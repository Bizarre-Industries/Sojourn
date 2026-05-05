# 0025 — Sparkle delta updates ship in v0.3.0

- **Status**: Accepted
- **Date**: 2026-05-03
- **Deciders**: Maintainer (skalghazali); Sojourn council (architect,
  security, devil-advocate, perf-skeptic, ux-critic).

## Context

ADR-0020 specified Sparkle + cask hybrid update model with full-DMG
appcast entries. `docs/process/plans/v0.3-plan.md` §"Why Sparkle delta
updates" promotes delta updates from "deferred" to "v0.3 in-scope":
full-DMG every release at ~30-80 MB × monthly cadence is ~600 MB/year
per user, while delta updates (`bsdiff` against the last release) run
4-8 MB. Wins for users on metered connections and cuts CDN costs.

Sparkle 2.x ships `generate_appcast` which handles delta generation
against a local archive of prior DMGs. `notarize.yml` already has the
Sparkle EdDSA signing scaffold from ADR-0020 (key vault path
`op://Bizarre-Industries/sojourn-sparkle-eddsa`). Adding delta
generation is a workflow-step + scripts addition; the wire format,
public key, and verification path are already established.

## Decision

`notarize.yml` adds a `generate_appcast` step that runs after
notarization and DMG creation. The step:

1. Uses `actions/cache` saved under the current release tag and restored
   by prefix to fetch the retained prior Sojourn DMGs into a local
   archive directory.
2. Reads the EdDSA signing key from
   `op://Bizarre-Industries/sojourn-sparkle-eddsa/private` via the
   1Password release environment, then pipes it on stdin to Sparkle's
   `generate_appcast --ed-key-file -` (no tempfile, no raw key
   command-line argument; matches ADR-0020 §"Key handling protocol").
3. Runs `generate_appcast --maximum-versions=10` against the archive
   directory. Output is `appcast.xml` with full-DMG and delta
   entries; signatures embedded per Sparkle spec.
4. Caps retention at 10 versions in the archive to bound storage and
   bandwidth growth.

`Sojourn/Services/SparkleService.swift` wraps
`SPUStandardUpdaterController` with the standard delta-aware code
path. Sparkle 2.x handles delta-apply transparently; no special code
needed in Sojourn beyond standard installer initialization.

v0.4 Stage 6 correction: Sparkle 2.9.1 already falls back from delta
download/apply failure to the regular update item before reporting a
terminal abort to the host app. Sojourn does not own a retry loop. The
delegate records terminal abort diagnostics only. Stage 6 also verified
that Sparkle 2.9.1 `SUErrors.h` code `4002` is `SUMissingUpdateError`,
not a delta-specific error code.

`project.yml` adds Sparkle to the Xcode-built Sojourn app target. The
SwiftPM library manifest intentionally does not depend on Sparkle:
`SparkleService` compiles a no-op same-API service only when
`SWIFT_PACKAGE` is set, while Xcode/app builds import Sparkle
unconditionally and fail if the package dependency regresses.

## Consequences

### Positive

- ~85% bandwidth saving per release for users on the delta path
  (4-8 MB vs 30-80 MB).
- Lower CDN cost (single GitHub Releases asset still serves both
  full and delta on demand).
- Sparkle 2 handles delta archive generation, signing, and
  delta-to-regular fallback before terminal errors reach Sojourn.
- Delta generation is a CI-side step; nothing in the running app
  changes day-to-day beyond initialization.

### Negative

- New Xcode package dependency adds maintenance surface (Sparkle
  releases must be reviewed before bump).
- `notarize.yml` workflow grows (one more step + cache + 1Password
  secret read). Retention math (10 versions) is a magic number that
  may need tuning if release cadence increases.
- Delta generation requires the prior DMG to be present in CI; cache
  miss on the first delta release after long quiet period falls back
  to full-DMG-only (acceptable degradation).
- Delta math errors still need clean-VM smoke coverage, but the
  fallback path is Sparkle-owned rather than a Sojourn retry loop.

### Neutral

- EdDSA signing path unchanged from ADR-0020; only the artifacts
  generated grow in number.
- Cask publish path (publish-homebrew-cask.sh) unchanged — cask still
  references the full DMG; delta is Sparkle-only.

## Alternatives considered

- **Defer delta to v0.4** — rejected. Maintainer decision in
  `v0.3-plan.md` §"Hard decisions" promotes delta to v0.3 explicitly.
- **Custom `bsdiff` pipeline outside Sparkle** — rejected. Reinventing
  what Sparkle ships is gratuitous; the framework's signing,
  fallback, and version-skip logic are tested production code.
- **Cask-only updates (skip Sparkle entirely)** — rejected. ADR-0020
  hybrid model is explicitly hybrid: cask for first install + new
  Macs, Sparkle for in-app upgrade UX. Removing Sparkle would push
  every upgrade into a `brew upgrade --cask sojourn` cycle, which is
  worse UX than in-app updates.
- **Compress full DMG harder (e.g., switch to xz / zstd)** — rejected.
  Marginal gains (~10-15%); doesn't approach the ~85% savings of
  delta updates. Also breaks `hdiutil`-based installer expectations.

## Council 2026-05-03 amendments

### User-visible behavior (update diagnostics)

Sparkle handles delta-to-regular fallback internally. Sojourn's
`SPUUpdaterDelegate` hook records terminal abort diagnostics for the
menu bar status surface and clears them after a successful update
cycle.

### Sparkle launch sequencing

`AppStore` owns `SparkleService`; `SojournApp` starts Sparkle from a
background `Task.detached` so appcast prefetch does not block menubar
appearance (200ms launch budget per v0.2 perf baseline). Appcast fetch
timeout is set to 30s explicitly via the updater delegate's
`URLSession` configuration (Foundation default 60s is too lenient).

### Council log

`/Users/binghzal/Developer/Sojourn/.Codex/council-logs/2026-05-03-v0.3-adr-batch.md`.
