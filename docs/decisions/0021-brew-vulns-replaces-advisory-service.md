# 0021 — `brew vulns` replaces `AdvisoryService`

- **Status**: Accepted
- **Date**: 2026-05-01
- **Deciders**: Sojourn maintainer

## Context

`Sojourn/Policy/AdvisoryService.swift` exists as a 92-line stub. Its
`refresh()` method is a no-op, and its data model assumes Sojourn
maintains its own CVE database — never wired up because doing so
properly is a multi-month project (CVE feed parsing, package-name
matching, dedup, OSV-format conversion).

In late 2025, Homebrew shipped
[homebrew-brew-vulns](https://github.com/Homebrew/homebrew-brew-vulns):
a first-party tap that wraps OSV.dev queries with Brewfile-aware
matching. `brew vulns` reports CVEs for installed formulae and casks
in OSV-format JSON, supports `--brewfile <path>` to scan declarative
state, and emits `--cyclonedx` (SBOM) and `--sarif` (code-scan)
formats for CI integration.

Now that Sojourn has dropped mpm for brew bundle (ADR-0018), the
ecosystem coverage of `brew vulns` matches Sojourn's coverage 1:1.
Reimplementing the same OSV query logic in Swift is a clear loss vs
a 5-line subprocess call.

## Decision

`Sojourn/Policy/AdvisoryService.swift` is rewritten as a thin shell-out
wrapper around `brew vulns --brewfile <path> --cyclonedx`. Sojourn:

1. Calls `brew vulns` via `Process` with **argv array**, never a
   shell-interpreted string. `Brewfile` path is resolved through
   `realpath` and validated to live under `~/.config/sojourn/` or the
   chezmoi source root before the call. A path containing
   shell-metacharacters fails closed (security council condition).
2. On first run, probes `brew tap-info homebrew/brew-vulns`. If the
   tap is missing, Sojourn surfaces a one-time UI prompt asking the
   user to consent to `brew tap homebrew/brew-vulns`. The Advisories
   pane shows "Tap not installed" until consent. **Auto-tap is never
   silent** (architect council condition + CLAUDE.md invariant 7).
3. Runs on a 24-hour cache schedule
   (`NSBackgroundActivityScheduler` task already running for
   `refresh-outdated`).
4. Parses the OSV-format JSON into Sojourn's existing `Advisory`
   struct (id, severity, summary, references, affected_versions).
   Parser caps response at **16 MB** and depth **32**; rejects on
   overflow (security council condition; DoS mitigation).
5. Persists the parsed result at
   `~/Library/Caches/Sojourn/advisories.json` (mode `0600`) with a
   24h TTL. Cache key = SHA-256 of the sorted Brewfile entries
   (perf council condition).
6. Surfaces findings in the Advisories pane with a three-state
   freshness indicator (UX council condition):
   - `fresh` — cache age < 24h. Pane header neutral.
   - `stale` — cache age 24h–7d, network or rate-limit failure on
     last refresh. Pane header shows "Last refreshed: 3 days ago.
     Tap to retry." (or similar non-alarmist copy).
   - `unavailable` — no cache, or cache > 7d. Pane shows
     "Advisories not yet checked. Run scan?" with explicit user
     action to call `brew vulns` synchronously.
7. On rate-limit response from OSV.dev (via `brew vulns`'s exit
   code or stderr), falls back to `stale` state with cached results
   up to 7 days old; never shows empty results during rate-limit
   (UX condition).

The `Advisory` model stays. The `refresh()` no-op is replaced by a
real implementation. The fixture corpus moves from "synthetic
hand-written advisories" to "real OSV samples checked in under
`SojournTests/Fixtures/advisories/` and updated via a CI nightly
that pulls 5 known-vulnerable Brewfile entries through `brew vulns`."

Council fires on this ADR per CLAUDE.md trigger ("Touches
`Sojourn/Policy/`") — write-time review of the new shell-out and
fixture refresh discipline.

## Consequences

### Positive

- 92 lines of dead code deleted; replaced by ~120 lines of real
  shell-out + parser. Net code grows but functionality goes from
  zero to real.
- OSV.dev is the canonical CVE feed for ecosystem-pinned packages
  in 2026; relying on it is correct, not a workaround.
- `brew vulns` updates without Sojourn rebuilds. CVE feed drift
  handled upstream.
- SBOM via `--cyclonedx` enables future supply-chain attestation
  features without re-implementing the format.

### Negative

- Network dependency on OSV.dev. If offline, advisories show as
  stale (cached 24h max). Mitigation: surface staleness in the
  Advisories pane header.
- `brew vulns` is a tap, not core. If the tap goes unmaintained,
  Sojourn must either fork or fall back. Mitigation: tap is
  Homebrew-org-owned (low fork risk); fall-back path is
  `brew tap-info`-driven detection at startup.

### Neutral

- 24h cache TTL matches brew's own advisory refresh cadence; users
  triggering an immediate scan via the UI re-runs the subprocess.
- ADR-0011's `SecretBroker` abstraction stays — advisories are
  unrelated to secret brokerage.

## Alternatives considered

- **Keep `AdvisoryService` stub, defer to v0.3** — rejected. The
  Advisories pane is in the v0.2 sidebar; shipping it as a no-op
  surface is misleading.
- **Bundle a static OSV mirror snapshot in the app** — rejected.
  CVE feeds drift weekly; a static snapshot is stale within a
  release cycle.
- **Reimplement OSV queries in Swift directly** — rejected.
  Multi-month engineering for parity with `brew vulns` that
  Homebrew maintains for free. YAGNI.
- **Use `osv-scanner` (Google's CLI) instead of `brew vulns`** —
  rejected for v0.2. `osv-scanner` is more general (Go modules,
  npm, Cargo, etc.) but doesn't understand Brewfile semantics.
  Brewfile is Sojourn's source of truth, so `brew vulns`'s
  Brewfile-aware mode is the better fit.
