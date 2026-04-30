# 0016 — Secret broker order: 1Password primary with cache + timeout, Keychain promoted, Bitwarden deferred

- **Status**: Accepted (lands in implementation-plan phase 14)
- **Date**: 2026-04-30
- **Deciders**: Sojourn maintainer
- **Supplements**: [0011-secret-broker-abstraction.md](0011-secret-broker-abstraction.md)

## Context

[0011-secret-broker-abstraction.md](0011-secret-broker-abstraction.md)
established the `SecretBroker` protocol and a detection ladder
(1Password → Bitwarden → Keychain → age → plaintext-refused). Q3 of audit §8
([process/open-questions.md](../process/open-questions.md))
deferred the order, default behaviour, and apply-path failure mode to the
maintainer.

The unaddressed problem in ADR-0011: `op` (1Password CLI) is in the hot
path of every `chezmoi apply` because every template function runs on
every apply, and every pull runs apply. In `account` mode (the recommended
default per
[reference/secret-brokers.md](../reference/secret-brokers.md#1password-mode-trade-offs)),
`op` does a network call to 1Password servers and respects session
timeouts. So: every pull on a flaky network, every pull during a
1Password API blip, every pull where the user's `op` session has timed
out, fails or stalls until re-auth. age has none of these failure modes —
local key, no network, no session.

The audit's recommended order also placed Bitwarden second. Bitwarden has
the same network + session properties as 1Password and requires an extra
CLI install (`bw`). Keychain is *always* present on macOS, requires no
extra install, no network, no session timeout. Keychain belongs ahead of
Bitwarden in the apply hot-path order.

## Decision

Detection ladder:

1. **1Password** (`op` CLI) — primary, **with**:
   - Per-secret last-success cache in macOS Keychain
     (`service: app.bizarre.sojourn.secret-cache`).
   - `secret_broker.read_timeout_seconds` (default 5).
   - On `op` timeout / outage, fall back to cached value with a visible
     banner "1Password unreachable; using cached secret from <date>".
   - Fail-closed only if no cache exists.
2. **macOS Keychain** (`keyring` chezmoi func) — secondary. Promoted from
   tertiary in ADR-0011 because of the always-present / no-network /
   no-session properties.
3. **age** — fallback, bundled per ADR-0009.
4. **Bitwarden** — **deferred to v1.1.** Strictly worse than Keychain in
   the apply hot-path. Re-evaluated post-v1 if user demand justifies.
5. **plaintext** — refused unless user explicitly waives per-file.

First-run bootstrap **prompts** if multiple brokers are detected:
"We see `op` and an age key; which broker do you want as default?"
This is the explicit-choice posture ADR-0011 already specifies under
"Alternatives considered → Auto-detect and pick one without user
confirmation — rejected." This ADR moves it from posture to actual
implementation.

Common-config defaults
([reference/secret-brokers.md](../reference/secret-brokers.md#common-configs-that-should-use-a-broker))
unchanged when 1Password is the chosen broker — `~/.aws/credentials`,
`~/.npmrc`, etc. still default to `op://` references.

## Consequences

### Positive

- Pull no longer breaks on transient 1Password unreachability for users
  with a cache.
- Keychain in the secondary slot covers the homelab / single-user case
  cleanly without a second password-manager install.
- Smaller v1 surface (three live brokers — 1Password, Keychain, age —
  not four).
- Explicit first-run prompt avoids the "Sojourn silently picked the
  wrong broker for me" failure mode.

### Negative

- One more piece of state to manage (per-secret cache in Keychain).
  Cache eviction on broker swap, manual flush in Settings → Secrets,
  diagnostics surface required.
- Cache freshness window is a security tradeoff: a rotated secret in
  1Password isn't picked up until the cache is invalidated. Mitigation:
  cache TTL of 7 days, manual flush button, banner shown when fallback
  fires.

### Neutral

- ADR-0011's `SecretBroker` protocol unchanged.
- Bitwarden re-introduction in v1.1 only requires a new actor + UI
  enable; protocol surface already accommodates it.

## Alternatives considered

- **Keep ADR-0011 order as-is (1Password → Bitwarden → Keychain → age)**
  — rejected. Apply-path failure mode unaddressed; Bitwarden adds
  install friction that Keychain doesn't.
- **age primary, 1Password optional** — rejected. Most Sojourn-target
  users already have 1Password installed; defaulting to age would force
  a manual broker swap for the common case.
- **No cache; fail-closed on `op` timeout** — rejected. Pull becomes
  unreliable; users stop using Sojourn when their secrets-bearing pull
  fails on a coffee-shop wifi.
- **Cache without timeout (always serve from cache, refresh in
  background)** — rejected. Stale cache becomes the default; rotated
  secrets propagate too slowly.
