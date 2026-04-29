# 0003 — Default 7-day cooldown for auto-updates

- **Status**: Accepted
- **Date**: 2026-04-24
- **Deciders**: Sojourn maintainer

## Context

Supply-chain attacks on package registries are now the dominant unprompted
malware vector for developer Macs. 2024–2026 incidents (axios, Shai-Hulud
1 + 2.0, s1ngularity / Nx, chalk/debug/tinycolor, ua-parser-js, Solana
web3.js, Ledger Connect Kit) had short exposure windows (2–8 hours) before
detection and removal. A short delay between upstream publish and Sojourn
auto-install dramatically reduces user exposure.

The 72-hour figure from 2020-era writeups is too aggressive given weekend
publish windows. 2026 industry consensus: Datadog, Renovate
(`config:best-practices`), Dependabot, Mend converge on 7 days; Snyk
hardcodes 21; uv supports configurable durations.

## Decision

Default cooldown is **7 days**. Per-tier deviations:

| Tier | Cooldown | Behaviour |
|---|---|---|
| A — Mac App Store | 0 | Auto |
| B — brew formulae, cargo | 7 days | Auto |
| C — casks, pinned pip/uv | 7 days | User prompt |
| D — global pip/pipx | 7 days | User prompt |
| E — global npm | 14 days | Never auto-update silently |

Advisory-aware bypass: if OSV / GHSA has a published advisory for the
**old** version, skip the cooldown and update.

## Consequences

### Positive

- Blocks every 2–8 hour incident on record outright.
- Maintains parity with major industry tools — users moving from
  Dependabot / Renovate to Sojourn don't have to relearn.
- Advisory bypass keeps users from being stuck on known-vulnerable old
  versions during the cooldown.

### Negative

- 7-day delay on legitimate updates. Users who want bleeding edge can
  override per-tier in Settings.
- Does not protect against multi-year maintainer infiltration (xz
  backdoor, CVE-2024-3094). User-facing copy must say so.

### Neutral

- Cooldown is per-package per-version; we record first-seen timestamp on
  daily refresh.
- Pre/postinstall script execution is gated separately (see
  [reference/cooldown-policy.md](../reference/cooldown-policy.md) "Hard
  rule").

## Alternatives considered

- **Snyk-style 21-day fixed** — rejected. Too long; users perceive Sojourn
  as falling behind.
- **3-day fixed** (Renovate npm default) — rejected. Misses weekend
  publish windows that incidents exploit.
- **No cooldown, advisory-only** — rejected. Misses zero-day window
  before advisories are published (typical detection-to-advisory delay
  exceeds incident exposure window).
