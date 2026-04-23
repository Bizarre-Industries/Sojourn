# Security — Sojourn

This document covers Sojourn's threat model, the cooldown-based supply-chain defense, the pre-commit secret-scanning flow, and how to report vulnerabilities.

## Threat model

Sojourn is a local desktop app. It runs as the user, not as a daemon. It does not host a network service. It has two exposure surfaces:

1. **The user's git remote.** Sojourn reads and writes a repo the user owns. If that remote is compromised, Sojourn on pull would apply whatever `packages.toml` and `chezmoi` sources it pulls, including `run_` scripts. Mitigation: pull previews every diff; `chezmoi apply --dry-run` before any `--force`; pre-operation snapshot to `.sojourn/backups/`.

2. **Package managers' upstream registries.** `mpm restore` shelling out to `brew install X` means trusting Homebrew's bottle source for X, the npm registry for an npm package, PyPI for a pip package, etc. This is the 2024–2026 supply-chain attack surface ([ARCHITECTURE.md §7](ARCHITECTURE.md#7-auto-update-safety-model)). Mitigation: cooldown + tier gating + OSV advisory bypass.

Not in scope: sandboxing user code Sojourn installs (Sojourn is a thin wrapper; the OS package managers' isolation is what it is), protecting against a kernel-level attacker, defending against physical access.

## Supply-chain cooldown

Default cooldown is **7 days** for auto-updates. Evidence base and per-ecosystem tier table in [ARCHITECTURE.md §7](ARCHITECTURE.md#7-auto-update-safety-model).

Hard rules:

- **Tier A (mas)**: auto, 0 cooldown. Apple reviews.
- **Tier B (brew formulae, cargo)**: auto, 7 day cooldown.
- **Tier C (casks, pinned pip/uv project deps)**: user prompt, 3–7 day cooldown.
- **Tier D (global pip/pipx)**: user prompt, 7 day cooldown.
- **Tier E (global npm)**: **never auto-update silently**, 14 day cooldown, user must approve each version.

Never auto-run an install that would execute `preinstall` / `postinstall` / build scripts without explicit user confirmation, even inside cooldown.

Advisory-aware bypass: if OSV / GHSA has a published advisory for the currently installed version, skip the cooldown and update. Sojourn hits `api.osv.dev` on the daily `NSBackgroundActivityScheduler` refresh.

What cooldown does **not** protect against: multi-year maintainer infiltration (the xz backdoor is the flagship case). User-facing copy should say so, so a user doesn't develop false confidence.

## Pre-commit secret scanning

Every auto-commit that Sojourn makes to the user's data repo runs through gitleaks first. Flow:

1. `SyncCoordinator` prepares a push candidate: new/updated files from `mpm backup`, `chezmoi re-add`, `defaults export`.
2. Invokes `gitleaks dir --staged --no-git --report-format json` (bundled binary at `Contents/Resources/bin/gitleaks`).
3. `SecretScanService` parses the JSON report into `[SecretFinding]`.
4. If findings are empty: proceed with the commit.
5. If findings are all low-confidence (entropy rules on uncommon patterns): show the user a modal with a "Commit anyway" button they can click immediately.
6. If any finding is a **high-confidence provider key** (AWS, GitHub PAT, OpenAI, Stripe live, Anthropic, Slack token): the "Commit anyway" button is disabled for 5 seconds and the modal shows a red banner with the match location. Forces the user to actually read before bypassing.

Default rules live in `Sojourn/Resources/data/gitleaks.toml`. Users can override per-repo with their own `.gitleaks.toml` in the data repo root (Sojourn merges).

## Bundled binary provenance

`gitleaks` and `age` ship in `Sojourn/Resources/bin/`. On each release:

1. `scripts/download-bundled-bins.sh` pulls them via authenticated `gh release download` from the canonical upstream repos.
2. `scripts/sign.sh` re-signs with Sojourn's Developer ID, hardened runtime, timestamp.
3. The outer `.app` notarization covers them.
4. `scripts/notarize.sh` asserts `spctl --assess --verbose=4` passes on the signed `.app` and `.dmg` before release upload.

Never bundle an unsigned binary. Never skip the `spctl` check.

## What the app does not do

- **Does not** store the user's git credentials in its own keychain. `git-credential-osxkeychain` is the default on macOS; Sojourn inherits the user's existing Keychain items for free.
- **Does not** embed any API secret. The optional GitHub Device Flow uses a `client_id` only — no `client_secret`. See [ARCHITECTURE.md §14](ARCHITECTURE.md#14-risks-and-unknowns) risk 7.
- **Does not** send telemetry, crash dumps, or install events to any Sojourn-operated server. No server exists.
- **Does not** request Full Disk Access unless the user explicitly opts into sandboxed-app preference sync.
- **Does not** symlink anything in `~/Library/Preferences`. See [ARCHITECTURE.md §8](ARCHITECTURE.md#8-plist-app-preference-sync-strategy).

## Reporting a vulnerability

Do **not** open a public GitHub issue for security-sensitive bugs. Email the maintainer at the address in `MAINTAINERS.md` (to be added), or use GitHub's private security advisory form on the repo.

Expect a response within 72 hours. Public disclosure timeline will be coordinated with the reporter; default is 90 days after a fixed release.
