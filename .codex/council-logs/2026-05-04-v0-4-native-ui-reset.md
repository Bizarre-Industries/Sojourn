# Council Log: v0.4 Native UI Reset

Date: 2026-05-04

## Trigger

Council fired because the final Stage 1 native UI reset deletes more than 100
lines in one commit. Review scope was the staged diff only; unstaged agent
tooling parity work was explicitly out of scope.

## Final Diff Under Review

- Replaced the main shell with a grouped `NavigationSplitView`, persisted pane
  selection, compact toolbar actions, and native list/group surfaces.
- Preserved pane accessibility identifiers and kept UI out of direct subprocess
  ownership.
- Added `AppStore` refresh snapshots, refresh-task coalescing, and parallel
  dashboard refresh awaits.
- Added `AppStore.pullSync()` / `pushSync()`, `JobRunner.track(...)`, bounded
  terminal job retention, latest-log reads, and explicit stream-truncation
  markers.
- Staged sync files before gitleaks, failed closed when secret scanning is
  unavailable, rejected unrelated pre-staged paths, delayed sync-push snapshots
  until after staged gitleaks passed, and committed only clean sync pathspecs.
- Restored menubar sync action identifiers and truthful sync status copy.
- Split the pane enum, menubar root view, and packages helper models into
  dedicated files so touched UI files stay under the 400-line invariant.
- Bumped `MARKETING_VERSION` to `0.4.0` and `CURRENT_PROJECT_VERSION` to `29`
  for Sojourn and MasHelper, then regenerated `Sojourn.xcodeproj`.

## Council Votes

### Architect

Decision: Approve with conditions.

Conditions:
- Packages pane policy display must align with ADR-0018/Brewfile tiers.
- Synthetic aggregate jobs (`Refresh Containers`, `Refresh macOS Features`)
  must not appear as subprocess jobs unless they map to real CLI work.
- Stream buffering must not silently drop or corrupt log output.

Resolutions:
- Packages pane now displays ADR-0018/Brewfile tier labels and windows,
  includes Flatpak, and avoids deriving the Packages summary from
  `CooldownPolicy`.
- Container and macOS feature refreshes no longer create synthetic aggregate
  `JobRunner` jobs. Brewfile refresh remains tracked as the exact brew dump
  subprocess work.
- `SubprocessRunner` records dropped stream chunks and emits a
  `[sojourn] stream output truncated ...` marker before finishing. A regression
  test covers the marker.

### Security

Decision: Approve with conditions.

Conditions:
- Runtime sync push must not accidentally commit unrelated files that were
  already staged in the user's data repository.
- Stage 1 must not include unrelated changes to secrets, policy, signing,
  gitleaks config, or agent-tooling parity files.

Resolutions:
- `SyncCoordinator.push` now checks `git diff --cached --name-only -z` after
  staging sync roots, rejects unexpected staged paths before scanning or
  snapshotting, attempts to unstage only Sojourn-added sync paths, and commits
  with an explicit pathspec. A regression test covers the blocked pre-staged
  path case.
- The staged Git scope excludes `AGENTS.md`, `CLAUDE.md`, `.gitleaks.toml`,
  `.github`, `.codex/commands`, hook parity files, `scripts/verify-agent-tooling.sh`,
  `Sojourn/Secrets`, `Sojourn/Policy`, signing config, and `notarize.yml`.
- Ignored `Sojourn/Config/local.xcconfig` was moved out of the checkout without
  reading or printing secret values so full redacted gitleaks can scan the
  repository.

### Devil's Advocate

Decision: Approve with conditions.

Conditions:
- Packages pane must align manager tiers/windows with ADR-0018 and include
  Flatpak.
- Push confirmation copy must match the real order: stage sync paths, scan,
  snapshot only after scan passes, then commit and push.

Resolutions:
- Packages pane now uses the Brewfile/ADR-0018 tier table for its visible
  policy surface, adds Flatpak, and labels ambiguous brew/cask rows as tier
  ranges where tap origin determines the stricter tier.
- Push confirmation copy now names the exact staged-path, gitleaks, post-scan
  snapshot, clean-path commit, and push sequence. Pull confirmation copy
  explicitly mentions rollback evidence in Generations.

### Perf Skeptic

Decision: Approve with conditions.

Conditions:
- Jobs pane current-log label must not replay the full 10,000-line log buffer
  just to show the latest line.
- Dashboard refresh awaits should not serialize independent refresh work.
- Refresh coalescing needs coverage for brew and one non-brew coalescer.

Resolutions:
- `LogBuffer` now exposes `latestLine()` and `subscribeLive()`; current job
  status reads one latest snapshot and subscribes only to future lines with a
  newest-one buffer.
- Dashboard refresh uses `async let` for independent brewfile, container, mas,
  generation, and macOS feature refreshes.
- Tests cover concurrent brewfile refresh coalescing into one tracked job and
  concurrent container refresh coalescing without synthetic jobs.

### UX Critic

Decision: Approve with conditions.

Conditions:
- Sync failures after toolbar push/pull must be visible in the main window
  with cause and recovery copy.
- Recovery buttons in the sync status banner must remain independently
  accessible to VoiceOver.
- Menubar status must not claim a clean writer state when sync is not
  configured, and existing `menubar.pull`, `menubar.push`, and `menubar.sync`
  identifiers must survive.
- Failure-dismissal copy should not imply retry, rollback, or cleanup.

Resolutions:
- `SyncPane` shows a top status banner for `.failed(reason)` and inbound
  pull-decision states. Toolbar status maps sync failure to "Sync needs
  attention" with an `xmark.octagon` icon and accessibility hint.
- The banner applies the combined accessibility label only to its text stack,
  leaving dismissal and conflict-review controls separate.
- Menubar sync status now derives from sync/conflict state, and the existing
  `menubar.pull`, `menubar.push`, and `menubar.sync` identifiers are restored.
- The failure button now says "Dismiss failure" with a hint explaining that it
  clears the message only and does not retry sync or undo staged files.

## Verification

- `bash scripts/regenerate-project.sh` passed.
- `swift build` passed.
- Targeted regression slice passed: 36 tests in 5 suites for
  `SubprocessRunnerTests`, `AppStoreTests`, `SyncCoordinatorTests`,
  `JobRunnerTests`, and `LogBufferTests`.
- `swift test` passed: 168 tests in 42 suites.
- `xcodebuild test -project Sojourn.xcodeproj -scheme Sojourn -destination 'platform=macOS,arch=arm64' -only-testing:SojournTests` passed:
  168 tests in 42 suites.
- `xcodebuild test -project Sojourn.xcodeproj -scheme Sojourn -destination 'platform=macOS,arch=arm64' -only-testing:SojournUITests` did not run tests locally because the runner bundle failed code-signing validation:
  `mapping process and mapped file (non-platform) have different Team IDs`.
- Manual Computer Use smoke covered all 11 sidebar panes and observed the
  expected pane accessibility identifiers: `pane.overview`, `pane.packages`,
  `pane.containers`, `pane.generations`, `pane.macos-features`,
  `pane.preferences`, `pane.sync`, `pane.machines`, `pane.advisories`,
  `pane.jobs`, and `pane.settings`. AppleScript automation was blocked by local
  Assistive Access/TCC.
- UI line counts remain under the invariant for touched split surfaces:
  `Components.swift` 175, `MenuBarRootView.swift` 338,
  `MainWindowView.swift` 368, `PackagesPane.swift` 359, and `SyncPane.swift`
  151 lines.
- `git diff --check` and `git diff --cached --check` passed.
- `gitleaks dir --config=.gitleaks.toml --no-banner --redact -v` passed after
  moving ignored `Sojourn/Config/local.xcconfig` out of the checkout without
  reading or printing secret values.

## Verdict

Proceed with the Stage 1 commit. Full signed UI automation remains release-gate
evidence for later v0.4 stages because the local UI-test runner is blocked by
Team ID signing, but Stage 1 has manual pane smoke evidence through Computer
Use.
