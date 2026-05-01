# 0020 — Sparkle EdDSA + cask `livecheck` hybrid update model

- **Status**: Accepted
- **Date**: 2026-05-01
- **Deciders**: Sojourn maintainer

## Context

Sojourn ships through two install paths:

1. **Cask** (`brew install --cask sojourn`) — most users. Updates
   surface via `brew upgrade --cask sojourn`. Cask's `livecheck`
   block tells brew where to find the latest release.
2. **Direct DMG download** (`Sojourn.dmg` from the GitHub Releases
   page) — for users who don't run brew, or who pre-date their brew
   install. Updates need an in-app mechanism since these users won't
   `brew upgrade`.

Sparkle is the de-facto macOS auto-update framework. It checks an
appcast XML, downloads the new DMG, verifies the EdDSA signature,
copies the new app over the old one, and relaunches. It does not know
or care about brew.

If only Sparkle is shipped: cask users get two update prompts (one
from Sparkle in-app, one from `brew upgrade`). If only cask is
shipped: direct-DMG users get no updates at all and silently rot on
old versions.

## Decision

Ship both, with clear ownership:

- **In-app Sparkle** is the primary updater. It runs on app launch,
  hits an appcast at
  `https://bizarre-industries.github.io/homebrew-sojourn/appcast.xml`,
  and prompts the user to download the new DMG. EdDSA signature is
  verified before relaunch.
- **Cask `livecheck`** points at the GitHub Releases page and lets
  `brew upgrade --cask sojourn` work for users who prefer the brew
  workflow.
- **Sparkle is suppressed when running under brew.** Sojourn reads
  `prefs.toml:install_source` (set on first launch via the detection
  sequence below). When `install_source = "cask"`, Sparkle's
  check-for-updates is silent — `brew upgrade` is the user's
  expected path.

EdDSA private key lives in 1Password (vault: `Sojourn`, item:
`sparkle-eddsa`, fields: `private` / `public`). CI reads it via the
`op` CLI using a service-account token in
`OP_SERVICE_ACCOUNT_TOKEN` (GitHub Actions secret). The public key is
baked into `Info.plist` at build time as `SUPublicEDKey`.

**Key handling protocol** (security council condition):

- The service-account token is scoped read-only to the single
  `op://Sojourn/sparkle-eddsa` item. Token cannot enumerate other
  vaults or items.
- The private key is **never written to disk**. The notarize workflow
  pipes `op read --no-newline op://Sojourn/sparkle-eddsa/private`
  directly into `sign_update -f -` (stdin pipe). No tempfile, no
  `--key-file` flag.
- After signing, `unset OP_SERVICE_ACCOUNT_TOKEN` runs in the same
  step. Subsequent steps cannot re-read the vault.
- CI runner logs are scrubbed via GitHub Actions'
  `add-mask` directive applied to both the token and the key bytes
  before any echo can leak them.

**Detection of cask install context** (UX + architect council condition):

The original "sniff `~/Library/Caches/Homebrew/Cask/sojourn--*.dmg`"
mechanism is brittle (`brew cleanup` purges the cache, brew may
relayout cache paths). Replace with **persisted install source**:

- On first launch, Sojourn writes `install_source` to `prefs.toml`
  (values: `"cask"` | `"dmg"` | `"unknown"`).
- Detection sequence at first launch only:
  1. If `$HOMEBREW_PREFIX/Caskroom/sojourn/<version>/` exists →
     `cask`.
  2. Else if `Sojourn.app` is at `/Applications/Sojourn.app` and was
     opened via Finder/dock (no caskroom receipt) → `dmg`.
  3. Else `unknown` (assume `dmg` for update behavior).
- Subsequent launches read `install_source` from `prefs.toml` and do
  not re-detect.
- The Updates pref pane offers a "Override install source"
  toggle for users who change paths post-install.

The appcast XML is hosted via GitHub Pages out of the
`Bizarre-Industries/homebrew-sojourn` tap repo (already public,
already serving the cask). Each release appends one
`<item>` element via the notarize workflow's
`sparkle-tools` step.

## Consequences

### Positive

- Both install paths get update notifications.
- Cask users update through their existing brew flow; no behavior
  change vs not having Sparkle.
- Direct-DMG users get a real updater and don't silently rot.
- EdDSA signature on the appcast prevents an attacker who controls
  the appcast XML host from pushing a malicious update — the user's
  app verifies before applying.

### Negative

- Two update mechanisms is two test surfaces. Mitigation: end-to-end
  test in `notarize.yml` that fakes a v0.2.1 release, generates the
  appcast entry, and verifies a v0.2.0 sandbox VM picks it up.
- Sparkle's framework adds ~3 MB to the bundle. Acceptable.
- Suppressing Sparkle inside cask requires runtime detection that
  could regress if brew changes its install layout. Mitigation:
  fail-open — if detection is wrong, the user sees a duplicate
  prompt, not a silent failure to update.

### Neutral

- Public EdDSA key change requires an app rebuild + notary submit. A
  key rotation is a major-version bump in practice.
- Appcast is publicly accessible; that's the point. Signature is
  the trust anchor, not URL secrecy.

## Alternatives considered

- **Sparkle only, no cask** — rejected. Forces all users onto a
  manual DMG download flow; brew-native users would lose the
  `brew upgrade` muscle memory.
- **Cask `livecheck` only, no Sparkle** — rejected. Direct-DMG users
  rot on old versions; Sparkle's signature verification is also a
  net security win.
- **Static-key Sparkle (DSA, the older mechanism)** — rejected. DSA
  is being deprecated in Sparkle 2.x; EdDSA is faster, simpler, and
  is the supported path going forward. New project = new key
  algorithm.
- **Delta updates (Sparkle's bsdiff support, ~85% bandwidth save)** —
  deferred to v0.3 per `docs/process/plans/v0.2-plan.md` §"Out of
  scope". Adds CI complexity (delta generation against prior
  release) without urgent benefit at v0.2's user base.
