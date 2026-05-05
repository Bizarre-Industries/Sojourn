# 0026 — Multi-machine conflict UX: refuse-and-show-diff

- **Status**: Accepted
- **Date**: 2026-05-03
- **Deciders**: Maintainer (skalghazali); Sojourn council (architect,
  security, devil-advocate, perf-skeptic, ux-critic).

## Context

ADR-0012 established a cooperative writer lock (`.sojourn/active.toml`)
that prevents simultaneous push from two Macs. The lock is
cooperative, not authoritative — git itself does not enforce locking.
v0.2 shipped the lock and `SyncCoordinator.pull` infrastructure but
the UX for "you have local commits + remote moved while your Mac was
asleep" is opaque: the current path bubbles git's stderr to the user
through `JobRunner` log output.

`docs/process/plans/v0.3-plan.md` §"Why explicit conflict UX" makes
the case: a proper conflict modal listing inbound commits + suggested
actions is small but load-bearing for the multi-machine value prop. A
fleet user pulls into a stale state daily; the UX must surface
incoming commits before they apply.

## Decision

v0.3 introduces `Sojourn/Sync/ConflictResolver.swift` (new directory
+ file) which owns a refuse-and-show-diff state machine extracted
from `SyncCoordinator.pull`. The state machine:

1. **detect** — `SyncCoordinator.pull` runs `git fetch` and asks the
   resolver whether local + remote diverged.
2. **list inbound commits** — resolver calls
   `GitService.inboundCommits(since:)` for structured commit metadata
   (sha, author, date, subject, file-stat summary).
3. **present diff** — `SyncPane` surfaces the inbound commit list +
   a per-file diff preview.
4. **user picks**:
   - **pull-rebase** — `git pull --rebase`; replays local commits on
     top of inbound.
   - **pull-merge** — `git pull --no-rebase`; merge commit recorded
     in history.
   - **abort** — leaves local state untouched; user resolves out-of-band.
5. **push refused until resolved** — `SyncCoordinator.push` queries
   the resolver's state; if conflict-pending, push is blocked with
   a descriptive error surface.

The refused push is the load-bearing safety: the cooperative lock is
defeatable by a Mac that was offline when the lock was acquired
elsewhere; the resolver's "must pull cleanly before push" gate
catches the post-lock case.

## Consequences

### Positive

- Multi-machine users see "your laptop pushed 3 commits to main while
  you were away — pull or abort" as a structured modal, not a wall of
  git stderr.
- Conflict resolution is in-app, no terminal context-switch.
- Push-refusal-until-pulled gate matches CLAUDE.md invariant 6: "A
  pull resolves any conflict before push is allowed."
- ConflictResolver is unit-testable with a local bare git repo as
  the "remote" — tests live under `SojournTests/Sync/`.

### Negative

- v0.3 SyncPane gains complexity: the segmented-control wrapper from
  v0.2 (HistoryPane + ConflictsPane + OnboardPane + MachinesPane
  picker) is replaced by a consolidated push/pull/history/conflicts
  surface that integrates the resolver. Larger pane file.
- Three-way merges (multiple Macs pushing in close succession past
  the cooperative lock) still require manual conflict resolution at
  the file level. Resolver presents the situation, doesn't fully
  automate. Acknowledged limitation.
- `GitService.inboundCommits(since:)` is a new public API surface;
  council fires on the addition (per CLAUDE.md trigger list:
  breaking change to a Service actor's public API).

### Neutral

- ADR-0012 cooperative writer lock unchanged; the resolver is a
  complement, not a replacement.
- `V02Stubs.swift` SyncPane wrapper is removed in this stage;
  `SyncPane.swift` extracted to its own file per the file-naming
  invariant ("File names match primary declaration").

## Alternatives considered

- **Auto-merge with conflict markers in working tree** — rejected.
  Default git behavior on `git pull` produces working-tree conflict
  markers that require terminal-level resolution. Defeats the
  in-app-resolution goal. Maintainer chose option (b)
  refuse-and-show-diff.
- **Always pull-rebase silently** — rejected. Hides the existence of
  inbound commits from the user; surprises when their local commits
  reorder against remote ones. Power users want explicit choice per
  pull.
- **Force-push wins** — rejected. Catastrophic for fleet sync; one
  Mac silently overwrites another's commits. Violates CLAUDE.md
  invariant 6 + "Never force-push a shared branch."
- **Force-take-writer (lock-stealing)** — rejected. Distinct from
  force-push: a Mac would forcibly claim `.sojourn/active.toml`
  from a stale lockholder without acknowledging in-flight remote
  commits. Still violates CLAUDE.md invariant 6 ("a pull resolves
  any conflict before push is allowed") because it bypasses the
  pull gate. v0.3-plan.md line 60 listed this as an option in the
  initial draft; council 2026-05-03 reconciled to drop it.
  Plan amended in the same commit.
- **Defer to v0.4** — rejected. Locked in maintainer's v0.3 scope per
  `v0.3-plan.md` §"Hard decisions". Multi-machine users hit this
  daily; it's the load-bearing UX gap from v0.2.

## Council 2026-05-03 amendments

### Copy spec

- **Modal title:** `"Remote moved. <N> commits inbound from <machine>."`
- **Buttons:**
  - `"Pull and rebase your work"` — runs `git pull --rebase`.
  - `"Pull and merge"` — runs `git pull --no-rebase`.
  - `"Cancel — leave local alone"` — internal state-machine name
    `abort`; user-facing label avoids git jargon.
- **Push-blocked surface:** `"Push blocked. Pull <N> commits first
  or cancel the pull-pending state in Sync."`
- **Stickiness:** Modal state is sticky — re-opening SyncPane
  re-presents the same conflict until resolved.

### Cross-pane conflict-pending visibility

When ConflictResolver state is conflict-pending:
- Sidebar Sync entry shows a small badge (matches v0.2 advisory
  three-state freshness pattern).
- OverviewPane surfaces a status row "Sync paused — `<N>` inbound
  commits pending review."

### Inbound-commit cap

- Hard cap at 200 commits via `--max-count=200` on the underlying
  `git log` argv.
- Cheap pre-check: `git rev-list --count origin/main..HEAD` runs
  before the heavier parse; skip the parse entirely when count is 0.
- Parsing happens in the GitService actor, NOT in SwiftUI view body.
- SyncPane commit list uses `LazyVStack` / `List` with `id: \.sha`
  (not `VStack` + `ForEach`).
- `git fetch` cadence: fires on user "Pull" gesture or
  cooldown-elapsed background sync only — NOT on every SyncPane
  appearance. JobRunner 30s timeout (advisory tier) on the fetch.

## v0.4 Stage 3 pull-apply review amendment

After a successful `git pull`, `SyncCoordinator` inspects pulled
`run_`, `run_once_`, and `run_onchange_` chezmoi scripts, chezmoi
templates (`*.tmpl` / `.chezmoitemplates`), install-capable Brewfile
entries, and unparsed Brewfile Ruby lines before any destructive
apply. If any are present, pull pauses in `awaitingPullApplyReview`
and the Sync pane lists the scripts/templates/packages. Push and fresh
Pull gestures are ignored while this review is waiting, so the
already-fetched state cannot be buried under a new sync action.

The review stores a content fingerprint over the displayed Brewfiles
and scripts. `Apply Listed Changes` recomputes that fingerprint before
capturing a generation and running `chezmoi apply` / `brew bundle
install`; if the content changed after review, Sojourn refuses to
apply and asks the user to rerun Pull and Apply. Reviewed apply exposes
step-level progress plus cancellation before each cancellable step.

This keeps ADR-0012's "pull resolves before push" gate intact while
adding the v0.4 consent rule: pulled executable lifecycle changes need
a second, reviewable gesture before they mutate the machine.

### Council log

`/Users/binghzal/Developer/Sojourn/.claude/council-logs/2026-05-03-v0.3-adr-batch.md`.
