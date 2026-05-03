# 0023 — Containers panel: detection priority + read-only display

- **Status**: Accepted
- **Date**: 2026-05-03
- **Deciders**: Maintainer (skalghazali); Sojourn council (architect,
  security, devil-advocate, perf-skeptic, ux-critic).

## Context

v0.2.0 deferred the Containers panel to v0.3 on timeline pressure
(see `docs/process/plans/v0.2-plan.md` deferral list and
`docs/process/plans/v0.3-plan.md` §"What this is"). Sojourn's value
prop is "carry your Mac config" — for any developer-adjacent user,
container-runtime configuration (Docker / OrbStack / Apple `container`
/ Lima / Colima) is part of that surface. v0.2's sidebar shipped
without a Containers entry; v0.3 adds it as the 11th sidebar pane.

Multiple container runtimes can coexist on one Mac and present
overlapping CLIs (`docker` may be backed by Docker Desktop or by
OrbStack's drop-in shim, for example). The pane needs an unambiguous
priority order so that "what's actually running" is reported
consistently.

## Decision

ContainersService probes runtimes in this fixed priority order and
reports the first installed runtime as the active backend, while
listing all installed runtimes:

1. **Docker Desktop** (`/Applications/Docker.app` + `docker --version`).
2. **OrbStack** (`/Applications/OrbStack.app` + `orb --version`,
   `docker --version` shim).
3. **Apple `container` CLI** (`container --version`).
4. **Lima** (`limactl --version`).
5. **Colima** (`colima version`).

v0.3 ships read-only detection + display only. No write actions
(start/stop daemon, run container, rebuild image). Read-only is in
scope; write actions are explicitly out of scope and revisited in
v0.4 if the maintainer's usage justifies them.

ToolLocator's existing candidate-path probing is the foundation —
ContainersService extends the same fixture-backed test pattern as
BrewBundleService and ChezmoiService. Per-runtime version-string
fixtures live under `SojournTests/Fixtures/containers/`.

## Consequences

### Positive

- 11th sidebar pane surfaces container-runtime state without inventing
  a new architectural pattern (extends ToolLocator + Service +
  fixtures).
- Priority order is auditable: priority comes from one ordered list in
  ContainersService, not from per-Mac heuristics.
- Read-only scope keeps v0.3 surface area bounded; no daemon-control
  blast radius.
- "Docker primary, OrbStack secondary" matches the maintainer's
  decision in `docs/process/plans/v0.3-plan.md` §"Hard decisions".
- Cross-machine drift on container runtimes becomes visible in the
  Machines pane via per-machine ContainersService snapshots.

### Negative

- A user running OrbStack as their daily driver while Docker Desktop
  is installed-but-unused will see Docker reported first. The pane
  surfaces both, but users may misread "first" as "the one I use."
  Mitigated by explicit "active runtime" badge on the highest-priority
  installed runtime, plus a version-only row (no last-launched
  timestamp — see step 2 implementation note).
- **OrbStack docker-shim impersonation.** OrbStack ships its own
  `docker` CLI shim (per OrbStack docs). A user with OrbStack-only
  who has a stale `/Applications/Docker.app` directory will be
  reported as "Docker Desktop installed" because filesystem-presence
  detection cannot distinguish the stale app from a working install.
  v0.3 read-only — UX confusion only. v0.4 write actions over this
  signal must resolve via socket-based liveness probe.
- Read-only-only means power users cannot manage containers from
  Sojourn. Acceptable for v0.3; reopen in v0.4.
- Lima + Colima are niche; their inclusion adds detection code with
  low usage probability. Cost is a few lines per runtime.

### Neutral

- No Brewfile additions: container runtimes are not bundled and not
  declared as Sojourn dependencies. The pane reports what's already
  installed.
- ToolLocator extended to probe additional candidate paths
  (`/usr/local/bin/colima`, `/opt/homebrew/bin/limactl`, etc.); same
  pattern as existing tools.

## Alternatives considered

- **OrbStack-first priority** — rejected. OrbStack is a faster runtime
  over Docker's protocol; treating it as the primary obscures the
  fact that Docker is the underlying daemon for most users with both
  installed. Maintainer decision.
- **User-configurable priority** — rejected for v0.3. Adds settings
  surface for a question that has one right answer per the maintainer.
  Reopen if user feedback contradicts.
- **Detect-active-runtime-via-socket** — rejected. Socket probing
  tests daemon liveness, not installation. The pane's job is to
  surface installed runtimes regardless of running state. (TCC was
  cited in an earlier draft; corrected by council 2026-05-03 — unix
  socket reads on `/var/run/docker.sock` do NOT trigger TCC for
  non-sandboxed apps. The real argument against socket probing
  remains: liveness ≠ installation.)
- **Skip Lima/Colima entirely** — rejected. Five runtimes is the
  comprehensive list; omitting two means users with those setups see
  an incomplete picture. The detection cost is small.
- **Defer the pane to v0.4** — rejected. Already deferred from v0.2;
  further deferral is plan drift. v0.3 plan locks the pane in.

## Council 2026-05-03 amendments

### ContainersService perf invariants

- Five version-probe subprocesses run with `async let` parallelism
  inside the actor (not sequential await).
- Filesystem-presence short-circuits the version probe. If the binary
  isn't at any `ToolLocator.candidateDirectories` path, the runtime
  is marked "not installed" without spawning the subprocess.
- Result is memoized for the lifetime of the AppStore. Refresh ONLY
  on (a) user-triggered "Rescan" button in ContainersPane, (b)
  BootstrapCoordinator's tool-locator invalidation event. NO
  timer-based re-probe.
- Each version-probe subprocess gets a 5s timeout (advisory tier per
  JobRunner timeout policy — anything slower is a hung binary).

### Empty + edge states

- **Zero runtimes installed.** Pane renders a single CTA "Install via
  Brewfile" linking to PackagesPane. No empty list, no spinner.
- **Runtime installed but never launched.** Row renders the runtime
  name + version + "Not yet launched" placeholder rather than a
  guessed timestamp.
- **Active-runtime badge accessibility.** `accessibilityLabel` is
  distinct from the visual ("Active runtime: Docker Desktop") so
  VoiceOver conveys the active state — color alone cannot.

### Council log

`/Users/binghzal/Developer/Sojourn/.claude/council-logs/2026-05-03-v0.3-adr-batch.md`.
