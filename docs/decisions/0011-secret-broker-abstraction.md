# 0011 — Secret broker abstraction (1Password primary, age fallback)

- **Status**: Proposed (lands in implementation-plan phase 14)
- **Date**: 2026-04-28
- **Deciders**: Sojourn maintainer

## Context

The v0.1 design treats age as the only secret broker. Audit
[process/audit-2026-04.md §2.6](../process/audit-2026-04.md#26-secret-broker-abstraction)
flagged this as the most under-leveraged feature for Sojourn's audience:

- chezmoi natively supports 20+ password-manager template functions:
  1Password (`onepasswordRead`, `onepassword`, `onepasswordItemFields`,
  `onepasswordDocument`), Bitwarden, KeePassXC, pass, macOS Keychain
  (`keyring`), Vault, Doppler, ejson, gopass, AWS/Azure/GCP secret stores.
- Most Sojourn-target users already have 1Password installed. The
  `op` CLI ships natively with the Mac app.
- age is the right answer for users without a password manager and for
  truly homelab-only setups.

## Decision

Introduce a `SecretBroker` protocol (audit §3.2.4) backed by per-provider
actors. Detection ladder:

1. **1Password** (`op` CLI present) — primary. Generate
   `{{ onepasswordRead "op://vault/item/field" }}` template stubs.
2. **Bitwarden** (`bw` CLI) — secondary.
3. **macOS Keychain** (chezmoi `keyring` template func) — tertiary.
4. **age** — fallback.
5. **plaintext** — refused unless user explicitly waives.

Common configs (`~/.aws/credentials`, `~/.npmrc`, `~/.pypirc`,
`~/.docker/config.json`, `~/.kube/config`, `~/.cargo/credentials.toml`)
become `op://` references by default when the broker ladder resolves to
1Password.

UI: "Insert secret reference" wizard in the Dotfiles pane. Secret Brokers
tab under Hygiene/Secrets per audit §4.1.2.

## Consequences

### Positive

- Users keep their secrets in their existing password manager — no
  migration required.
- Secrets never enter the git repo as ciphertext (which still leaks
  metadata: byte length, change frequency).
- Aligns with chezmoi's native model; less Sojourn-side code.

### Negative

- Detection complexity: `op` ships at multiple paths (Homebrew + the
  desktop app's CLI integration). Audit §6.6 calls this out.
- Network dependency on 1Password servers when reading.
- Per-provider quirks (1Password's account/connect/service mode trade-off
  per audit §2.6.4).

### Neutral

- age stays bundled (per
  [0009-bundle-binary-policy.md](0009-bundle-binary-policy.md)) for
  fallback scenarios.

## Alternatives considered

- **age-only** (status quo) — rejected. Misses the 1Password native
  surface that solves the problem upstream.
- **Sojourn-built secret manager** — rejected. Building a password
  manager is a separate product; chezmoi already has the integration
  surface.
- **Auto-detect and pick one without user confirmation** — rejected.
  Secret broker choice should be explicit, surfaced in onboarding.
