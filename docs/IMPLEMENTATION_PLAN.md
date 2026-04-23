# Sojourn — Full Implementation Plan (v0.1 → v1)

## Context

Sojourn is a macOS 14+ SwiftUI app for cross-Mac setup sync (packages via `mpm`, dotfiles via `chezmoi`, prefs via `defaults`). As of 2026-04-24 the repo has complete design docs and skeletal stubs only — every service/view/store is a docstring-only shell. This document sequences the implementation to land v1 scope per [ARCHITECTURE.md §15](ARCHITECTURE.md#15-proposed-v1-scope-cut).

Execution contract: autonomous commits on `main`. Every phase passes `swift test` + (eventually) `xcodebuild test` + `gitleaks dir` before commit. Fixture-backed tests mandatory per [CLAUDE.md](../CLAUDE.md).

---

## Phase 0 — Xcode project + xcodegen

Generate `Sojourn.xcodeproj` via `xcodegen` with targets Sojourn (app), SojournTests (Swift Testing), SojournUITests (XCUITest). Add `project.yml`, `Sojourn/Config/{Debug,Release}.xcconfig`, `scripts/regenerate-project.sh`. Wire Info.plist, entitlements, Resources.

## Phase 1 — Core infra

Real `SubprocessRunner` (swift-subprocess + raw Process/Pipe/AsyncStream fallback, 64KB backpressure, PTY wrap option, cancellation). `JobRunner` @MainActor @Observable owning Task per Job. `LogBuffer` ring buffer with broadcaster. `ANSIParser` SGR state machine → AttributeContainer. `ToolLocator` candidate-path probe + Xcode CLT detection.

## Phase 2 — Models + persistence

Models: AutoUpdateTier, Conflict, Snapshot, HistoryEntry, DotfileOwner, OrphanCandidate, PreferenceDomain, Job (moved). Persistence: SojournFileCodec (handwritten TOML), BackupsDirectory (30d retention), AppSupportPaths, SettingsStore, DeletionsDB (SQLite). Extend AppStore.

## Phase 3 — Subprocess service actors

**3a GitService** — `/usr/bin/git` porcelain v2 -z. **3b MPMService** — mpm 6.x `--table-format json`, parallel per-manager fanout, 90s timeout. **3c ChezmoiService** — `chezmoi managed/status/diff/apply` with `--no-pager --color=false`. **3d PrefService** — `defaults export/import`, `plutil -convert xml1`, FDA canary probe, app quit/relaunch. **3e SecretScanService** — bundled `gitleaks dir --staged --report-format json`, classifies high-severity (AWS/GitHub PAT/OpenAI/Stripe) with 5s UI lockout. **3f BrewService** — signed .pkg install via `/usr/sbin/installer` with Authorization. **3g BootstrapService** — state machine per §9. **3h GitHubDeviceAuth** — OAuth Device Flow, client_id only, Keychain-stored token.

## Phase 4 — Sync coordinator + snapshots

`SnapshotService` (per-op backup to `~/Library/Application Support/Sojourn/backups/<ts>-<op>/`). `SyncCoordinator` push/pull orchestration per §6. `CooldownGate` with OSV advisory bypass. `BackgroundActivity` with `NSBackgroundActivityScheduler` (`app.bizarre.sojourn.refresh-outdated`, 1h/15m tolerance).

## Phase 5 — Cleanup / orphan detection

`CleanupService` scans dotfiles (via `data/dotfile_owners.toml`) + `~/Library/**` (bundle-ID reconciliation). Classifies safe/review/risky. Uses `NSFileManager.trashItem` + DeletionsDB log. Never `rm`. Populate dotfile_owners registry (~60 entries) and applications registry (~100 top apps).

## Phase 6 — UI

Full SwiftUI surface: Sidebar, Packages/Dotfiles/Preferences/History/Machines/Cleanup panes, OnboardingFlow, PushPullBar, ConflictResolutionView, SecretFindingsModal (5s lockout), SettingsScene, MenuBarRootView, BootstrapView, LogConsoleView. Logical-accessibility UI tests.

## Phase 7 — Release pipeline

Real `download-bundled-bins.sh` (gitleaks + age via `gh release download`, codesign `--options=runtime`). Real sign/notarize/dmg/cask scripts. CI workflows: ci.yml (swift test + xcodebuild test + gitleaks), notarize.yml (tag-triggered full release), codeql.yml weekly. MAINTAINERS.md, THIRDPARTY.md.

## Phase 8 — Docs expansion

`docs/SUPPORTED_MANAGERS.md`, `docs/RELEASE.md`, `docs/CONFLICTS.md`, `docs/PREFS_DOMAINS.md`. Extend SECURITY.md (threat model diagram, allowlist procedure). Extend ARCHITECTURE.md §17 Testing, §18 Observability (OSLog categories).

## Phase 9 — Polish

`.swift-format`, `.swiftlint.yml`, accessibility audit, ASan test run.

---

## Verification per phase

1. `swift test` passes.
2. `xcodegen generate && xcodebuild test -scheme Sojourn -destination 'platform=macOS'` passes (post-phase-0).
3. `gitleaks dir --config=.gitleaks.toml` passes.
4. `git commit -s` + `git push origin main`.

## Out of scope (defer to v2 per §15)

Sandboxed-app prefs, concurrent-write merge, pnpm, SwiftTerm pane, `SMAppService.agent`, Mac App Store, non-mac platforms, hosted backend.
