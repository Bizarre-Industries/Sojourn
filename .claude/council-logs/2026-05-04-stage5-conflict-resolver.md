# Council 2026-05-04 — v0.3 stage 5: SyncPane + ConflictResolver

**Trigger**: `Service` actor public API change (`GitService` adds `fetch`, `inboundCommits`, `pullRebase`, `pullMerge`, `parseInboundCommits`, `rebaseAbort`, `mergeAbort`).

**Diff scope**:
- New: `Sojourn/Models/InboundCommit.swift`, `Sojourn/Sync/ConflictResolver.swift`, `Sojourn/UI/Panes/SyncPane.swift`, `SojournTests/Sync/ConflictResolverTests.swift`, `SojournTests/Services/GitServiceInboundCommitsTests.swift`, `SojournTests/Fixtures/git/inbound-commits.txt`.
- Modified: `Sojourn/Services/GitService.swift`, `Sojourn/Sync/SyncCoordinator.swift`, `Sojourn/Store/AppStore.swift`, `Sojourn/UI/Panes/ConflictsPane.swift`, `Sojourn/UI/MainWindowView.swift`, `Sojourn/UI/Components.swift`, `SojournTests/Sync/SyncTests.swift`, `project.yml`, `.gitleaks.toml`.
- Deleted: `Sojourn/UI/Panes/V02Stubs.swift` (SyncPane extracted).
- Build: `CURRENT_PROJECT_VERSION` 24 → 25 both targets.

## Verdicts

| Member | Decision |
|---|---|
| architect | APPROVE-WITH-CONDITIONS |
| security | APPROVE-WITH-CONDITIONS |
| perf-skeptic | APPROVE-WITH-CONDITIONS |
| ux-critic | APPROVE-WITH-CONDITIONS |
| devil-advocate | APPROVE-WITH-CONDITIONS |

## Conditions accepted in this commit

- **security #1**: `--` separator added to `aheadBehind` and `inboundCommits` argv (`GitService.swift`); revspecs starting with `-` rejected with `GitError`.
- **architect #1**: `.blockedFromPush` is now a recoverable pre-pull state — `SyncCoordinator.pull` resets the resolver before `detect` so a user who chose Abort can retry.
- **architect #2**: `ConflictResolver.detect` is idempotent — early-returns if state is already `.detecting`.
- **architect #3**: `ConflictResolver.apply` runs `git rebase --abort` / `git merge --abort` on failure to restore the working tree. New `GitService.rebaseAbort` + `GitService.mergeAbort` methods.
- **devil-advocate #3**: sidebar Sync badge is count + glyph (`exclamationmark.circle.fill`) instead of color-only dot. Addresses ux-critic deuteranopia note in the same change.
- **ux-critic auto-route**: `SyncPane.didAutoRoute` `@State` guard — first appearance routes to Conflicts tab; user can manually navigate to History without being snapped back.

## Conditions deferred (tracked as v0.3 follow-ups)

- **perf-skeptic #1**: 30s `JobRunner` advisory timeout for `git fetch` per ADR-0026 amendment. Stage 5 ships with the existing 60s `runCommand` default. Wire JobRunner advisory tier into `GitService.fetch` before v0.3.0 tag — likely adjacent to stage 6 work.
- **perf-skeptic #2**: `Task.checkCancellation()` between awaits in `ConflictResolver.detect`. Bundled with the JobRunner wiring.
- **security #2**: pin `Text(_ String)` non-LocalizedStringKey contract via test. Defer — current SwiftUI behavior matches contract; risk is regression-prevention only.
- **security #3**: document local gitconfig trust in ADR-0026 amendments. Defer to ADR amendment alongside the next signing-touching change.
- **ux-critic confirmation dialog** on rebase/merge buttons + i18n + accessibility-combine on commit rows. Defer — pattern improvements that should land alongside the broader UI accessibility pass; tracked in v0.4 backlog.
- **ux-critic resolved-state Push affordance**: defer; HistoryPane already exposes Push.
- **devil-advocate auto-rebase fast-forward-clean**: rejected for v0.3. ADR-0026 explicit user-choice gate is intentional. Re-evaluate if telemetry shows users always pick rebase.
- **devil-advocate inline ConflictResolver into SyncCoordinator**: rejected. Separate file keeps the state-machine testable in isolation; ConflictResolverTests would not cleanly factor into SyncTests.

## Files

- `/Users/binghzal/Developer/Sojourn/Sojourn/Sync/ConflictResolver.swift`
- `/Users/binghzal/Developer/Sojourn/Sojourn/Services/GitService.swift`
- `/Users/binghzal/Developer/Sojourn/Sojourn/Sync/SyncCoordinator.swift`
- `/Users/binghzal/Developer/Sojourn/Sojourn/UI/Panes/ConflictsPane.swift`
- `/Users/binghzal/Developer/Sojourn/Sojourn/UI/Panes/SyncPane.swift`
- `/Users/binghzal/Developer/Sojourn/Sojourn/UI/MainWindowView.swift`
- `/Users/binghzal/Developer/Sojourn/Sojourn/Store/AppStore.swift`
- `/Users/binghzal/Developer/Sojourn/Sojourn/Models/InboundCommit.swift`
- `/Users/binghzal/Developer/Sojourn/SojournTests/Sync/ConflictResolverTests.swift`
- `/Users/binghzal/Developer/Sojourn/SojournTests/Services/GitServiceInboundCommitsTests.swift`

## Verification

- `swift build` → clean (zero warnings on changed files).
- `xcodebuild test -scheme Sojourn -destination 'platform=macOS,arch=arm64' -only-testing:SojournTests` → TEST SUCCEEDED.
- `gitleaks dir . --no-banner` → no leaks (`.agents/` allowlisted alongside `.claude/`).
