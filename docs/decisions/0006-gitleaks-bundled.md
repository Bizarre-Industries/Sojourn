# 0006 — Bundle gitleaks for pre-commit secret scanning

- **Status**: Accepted
- **Date**: 2026-04-24
- **Deciders**: Sojourn maintainer

## Context

Every auto-commit to the user's data repo could leak credentials (AWS keys
in `~/.aws/credentials`, GitHub PATs in `~/.gitconfig`, OpenAI keys in
shell history files chezmoi might pick up, Stripe live keys in app
configs). A pre-commit secret-detection step is mandatory.

The candidate scanners:

- **gitleaks** — MIT, ~8 MB static Go binary, mature ruleset, fast.
- **trufflehog** — AGPL-3.0, larger binary, slower; verification mode
  requires network egress (privacy regression).
- **detect-secrets** — Python, requires interpreter, ~30–60 MB via
  PyInstaller, low-velocity Yelp maintenance.

## Decision

Bundle **gitleaks v8.30.1+** at `Contents/Resources/bin/gitleaks`.
Re-sign with Sojourn's Developer ID under `--options=runtime`; staple as
part of outer notarization. Invoke via
`gitleaks dir --staged --no-git --report-format json` before every
auto-commit.

## Consequences

### Positive

- Fast: scan completes in <1s for typical dotfile/preference diffs.
- Conservative default ruleset; user-overridable per repo via
  `.gitleaks.toml` allowlist.
- High-confidence provider keys (AWS / GitHub PAT / OpenAI / Stripe live)
  trigger a 5-second UI lockout on the "Commit anyway" button — forces
  the user to read.

### Negative

- Bundled binary adds ~8 MB to the DMG.
- Re-signing burden on every release.

### Neutral

- chezmoi's built-in `betterleaks` (since v2.70.2) is complementary, not
  redundant. It runs on `chezmoi add` and warns; gitleaks runs on
  pre-commit and gates.

## Alternatives considered

- **trufflehog** — rejected. AGPL-3.0 adds legal surface area for a local
  desktop. Verification mode requires network egress.
- **detect-secrets** — rejected. Python interpreter dependency; large
  binary; low-velocity upstream.
- **No scanner; rely on chezmoi `betterleaks`** — rejected. betterleaks
  is embedded in chezmoi; the user has no control over rules from the
  Sojourn app layer.
