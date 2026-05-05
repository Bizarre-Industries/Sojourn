# Changelog

All notable changes to Sojourn. Follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[SemVer](https://semver.org/).

## [Unreleased]

### Added

- v0.4 stage 1 native UI reset: grouped split-view sidebar,
  compact toolbar actions, native pane surfaces, AppStore-backed
  pane snapshots, bounded job history, and staged-content secret
  scanning before sync push.
- v0.4 stage 2 pane data completion: real Brewfile package inventory
  rows, expanded generation/advisory/container/preference metadata,
  and Swift/UI smoke coverage for the package inventory surface.

### Planned (post-v0.3.0)

(See `docs/process/plans/v0.4-plan.md` for the active native UI reset plan.)

## [0.3.0] — 2026-05-04

Released from commit `eabe574`. Build numbers 21 → 28 walked through
stages 1-8.

### Added

- ADR-0023 (containers panel detection priority).
- ADR-0024 (mas Touch-ID privileged helper via `SMAppService`).
- ADR-0025 (Sparkle delta updates).
- ADR-0026 (multi-machine refuse-and-show-diff conflict UX).
- `Sojourn/Services/ContainersService.swift` — actor probing 5 runtimes
  (Docker, OrbStack, Apple `container`, Lima, Colima) in fixed
  priority order with `async let` parallelism + filesystem-presence
  short-circuit + 5s per-probe timeout. Read-only.
- `Sojourn/UI/Panes/ContainersPane.swift` — 11th sidebar pane;
  read-only display; "Active runtime" badge with accessibility label;
  empty-state CTA; manual rescan.
- `Pane.containers` enum case + `MainWindowView.detail(for:)` arm.
- `AppStore.containersService` + `containers` snapshot +
  `refreshContainers(forceRescan:)`.
- `SojournTests/Services/ContainersServiceTests.swift` — 17 tests
  (parser fixtures for all 5 runtimes, priority order, snapshot
  active-runtime resolution).
- 5 fixtures under `SojournTests/Fixtures/containers/` — real-shape
  `<tool> --version` output snapshots.
- `JobKind` enum (installUpgrade / advisory / snapshot) on
  `JobRequest` with default `.advisory`. Per-tier hard timeouts:
  install/upgrade exempt; advisory 30s; snapshot 600s. Watchdog Task
  fires `markTimedOut(_:after:)` on expiry; terminal-state guard on
  every `mark*` helper prevents post-termination overwrite.
- `SojournTests/Services/JobRunnerTimeoutPolicyTests.swift` — 12
  tests covering the policy table, JobRequest defaults +
  effectiveTimeout fallback, watchdog overrun, install/upgrade
  exemption, natural-completion vs watchdog race, cancel vs
  watchdog non-interference.
- `Sojourn/Sync/ConflictResolver.swift` — refuse-and-show-diff state
  machine (clean / detecting / conflictPending / resolving / resolved
  / blockedFromPush / failed) per ADR-0026. Idempotent `detect()`
  guard; `apply(_:)` cleans up via `git rebase --abort` /
  `git merge --abort` on failure.
- `Sojourn/Services/GitService.swift` gains `fetch`, `inboundCommits`,
  `pullRebase`, `pullMerge`, `parseInboundCommits`, `rebaseAbort`,
  `mergeAbort`. Revspec args separated by `--`; revspecs starting with
  `-` rejected (council 2026-05-04 stage5 security condition).
- `Sojourn/Models/InboundCommit.swift` — Sendable + Identifiable value
  type for inbound commit metadata (sha, author, ISO8601 date,
  subject, file-stat).
- `Sojourn/UI/Panes/SyncPane.swift` — extracted from V02Stubs.swift
  (deleted); first-appearance auto-routes to Conflicts tab when
  conflictPending, guarded by `didAutoRoute` so manual navigation
  sticks.
- `Sojourn/UI/Panes/ConflictsPane.swift` — replaces v0.2 stub with
  state-driven UI per ADR-0026 copy spec ("Pull and rebase your
  work" / "Pull and merge" / "Cancel — leave local alone"). Uses
  `List(commits, id: \.sha)` row recycling per ADR-0026 amendment.
- `SyncCoordinator.pull` runs `ConflictResolver.detect` first; if
  inbound commits present, sets `phase = .awaitingPullDecision(...)`
  and returns. `.blockedFromPush` is recoverable — pull resets the
  resolver before re-detecting.
- `SyncCoordinator.push` refuses while `ConflictResolver.canPush` is
  false; surfaces `pushBlockedReason` to the user.
- `SyncPhase.awaitingPullDecision([InboundCommit])` enum case for the
  conflict-pending phase. `Components.swift::phaseLabel` extended.
- `MainWindowView` sidebar shows `<count>` plus
  `exclamationmark.circle.fill` glyph when ConflictResolver is
  conflictPending / blockedFromPush / failed (count + glyph over
  color-only dot per council 2026-05-04 amendment).
- `SojournTests/Sync/ConflictResolverTests.swift` — 6 end-to-end
  tests using a local bare git repo as the remote.
- `SojournTests/Services/GitServiceInboundCommitsTests.swift` — 7
  parser-only tests against
  `SojournTests/Fixtures/git/inbound-commits.txt`.
- `.gitleaks.toml` allowlists `.agents/` (gitignored plugin dir
  triggers false-positive Apple-app-specific-password matches on
  swiftui-expert-skill heading anchors).
- Sparkle Xcode package dependency `sparkle-project/Sparkle 2.9.x`
  for in-app delta updates (ADR-0025).
- `Sojourn/Services/SparkleService.swift` — `@MainActor` wrap of
  `SPUStandardUpdaterController` + `SPUUpdaterDelegate`. AppStore-
  owned (no singleton); eagerly constructed via `Task.detached` from
  `SojournApp .task` so the menubar 200ms launch budget is preserved.
  `feedURLSession(for:)` pins appcast fetch to 30s. `didAbortWithError`
  inspects `SUDeltaUpdateError = 4002` (domain `SUSparkleErrorDomain`)
  and falls back to full DMG with status string "Update download
  restarting (delta unavailable)". Fallback-loop guard
  (`hasFallenBackThisSession`) prevents recursion.
- `Sojourn/App/SojournApp.swift` — menubar `Check for Updates…`
  command in `CommandGroup(after: .appInfo)`, gated on
  `sparkleService.canCheckForUpdates`.
- `Sojourn/Info.plist` — `SUFeedURL` →
  `https://github.com/Bizarre-Industries/Sojourn/releases/latest/download/appcast.xml`,
  `SUPublicEDKey` placeholder (notarize.yml fails the build if not
  replaced before tag), `SUEnableAutomaticChecks`,
  `SUScheduledCheckInterval = 86400`.
- `appcast.xml` — empty channel scaffold; `generate_appcast`
  populates per release.
- `.github/workflows/notarize.yml` — pre-sign placeholder fail
  (`grep -q PLACEHOLDER`), 1Password Sparkle private-key load,
  empty-key fail-loud, stdin-only `generate_appcast --ed-key-file -`
  signing from the Xcode-resolved Sparkle package artifact, upload
  `appcast.xml` + delta archives to GitHub Release.
- `Package.swift` includes `Services/SparkleService.swift` in the SPM
  library build; the file compiles a no-op same-API updater only when
  `SWIFT_PACKAGE` is set. Xcode app builds import Sparkle
  unconditionally via `project.yml`.
- `BootstrapState.installingMas` — additive enum case for the
  `brew install mas` step in `BootstrapService.proceed()`.
  `probeTools` now includes `mas` so the bootstrap rail surfaces
  the install latency.
- `Sojourn/UI/Modals.swift::BootstrapView` rail extended to 8 steps
  (PROBE / CONSENT / XCODE CLT / HOMEBREW / MPM / CHEZMOI / MAS /
  READY); progress fractions adjusted; `STEP n / 8` labels.
- `Sojourn/UI/Panes/OnboardPane.swift` — replaced v0.2 stub with
  inline bootstrap status row + "Setup new dotfiles repo" section.
  "Copy repro-drift issue template to dotfiles repo" button uses
  `fileImporter`, security-scoped resource access, and `FileManager`
  to write `<repo>/.github/ISSUE_TEMPLATE/repro-drift.md`.
- `Sojourn/Resources/data/repro-drift.md` — bundled template
  (matches `.github/ISSUE_TEMPLATE/repro-drift.md`) so the copy
  flow runs offline.
- `SojournTests/Services/BootstrapServiceMasInstallTests.swift` —
  5 tests (probeTools shape, installingMas pattern-match, bundle
  resolution).
- `MasHelper` Xcode target (Swift command-line tool) — privileged
  daemon binary `industries.bizarre.Sojourn.helper` embedded at
  `Sojourn.app/Contents/MacOS/`. Listens on
  `industries.bizarre.Sojourn.helper.mach`. Per-connection
  `setCodeSigningRequirement` validation gates every XPC call (DEBUG
  builds skip; Release builds pin to Sojourn's Developer ID
  identifier). Helper-side 600s subprocess cap with SIGTERM+SIGKILL
  watchdog. argv discipline: App Store IDs cross XPC as
  `NSNumber<UInt64>` validated `> 0` before reaching `Process`.
- `Sojourn/Services/MasHelperProtocol.swift` — shared `@objc` XPC
  contract + constants (mach name, bundle id, plist name, sentinel
  exit codes, 600s timeout). Compiled into both targets.
- `Sojourn/Services/MasHelperClient.swift` — XPC client actor
  bridging reply-block API to `async throws`. Symmetric per-connection
  code-signing pin on Release builds.
- `Sojourn/Services/MasService.swift` — high-level wrapper over
  `SMAppService.daemon(plistName:)` lifecycle (register / unregister
  / status) + forwards install/upgrade to `MasHelperClient`.
- `Sojourn/Store/AppStore.swift` — `masService` member,
  `masHelperStatus` observable, `refreshMasHelperStatus()` /
  `registerMasHelper()` / `unregisterMasHelper()` async methods.
- `Sojourn/UI/Panes/PackagesPane.swift` — "Touch-ID install helper
  active" status row (visible when `mas` manager selected) with
  StatusDot + Register/Revoke button + accessibility label distinct
  from color (per ADR-0024 council 2026-05-03 amendment).
- `MasHelper/Info.plist` — `SMAuthorizedClients` requirement string
  pinning Sojourn's Developer ID identifier.
- `MasHelper/Launchd.plist` — daemon plist embedded into
  `Sojourn.app/Contents/Library/LaunchDaemons/` via postBuildScript
  for `SMAppService.daemon(plistName:)` to find at register time.
- `project.yml` postBuildScript embeds helper binary into
  `Contents/MacOS/` + re-codesigns with hardened runtime + entitlements
  using whichever identity is available (Developer ID in CI, ad-hoc
  locally).
- `SojournTests/Services/MasHelperClientTests.swift` — 14 tests cover
  protocol constants (mach name, bundle id, sentinels),
  `MasInvocationResult` accessors, error descriptions + equality,
  client UInt64 input validation (rejects zero ID + zero in upgrade
  list).

### Fixed

- SwiftPM builds now include `SparkleService` behind a `SWIFT_PACKAGE`
  gate, falling back to a no-op updater service for `swift build` /
  `swift test` while app/Xcode builds require Sparkle.
- SwiftPM resources now include `Resources/preference-domains.json`, and
  the bundled repro-drift template resolves through a package-aware
  resource locator.
- `notarize.yml` avoids direct GitHub expression interpolation inside
  shell scripts and verifies Homebrew with shell commands instead of the
  unpinned `Homebrew/actions/setup-homebrew@main` action.
- `make ci-local` has one release-gate target for workflow lint,
  gitleaks, pinned-action checks, zizmor, expiry validation, and
  advisory Swift lint/format checks.
- Build metadata is aligned to v0.3 stage 8 build `28`, and UI smoke
  tests cover the current 11-pane sidebar including Containers and the
  `pane.macos-features` identifier.

## [0.2.0] — 2026-05-01

This is the canonical v0.2 release. Earlier failed v0.2.0 → v0.2.7
attempts (cask-publish chain failures, all on the same day) were
deleted; the v0.2.0 tag was force-moved to the working state. Single
tag, repeatedly iterated on until the release pipeline went green.

### Added

- Homebrew tap repository at `Bizarre-Industries/homebrew-sojourn`,
  seeded with `Casks/sojourn.rb` at v0.2.0 with the real DMG sha256.
- `scripts/publish-homebrew-cask.sh` — direct-push publisher invoked
  by `notarize.yml`. Shellcheck-clean. `--dry-run` flag for local
  validation. Structured exit codes (1 precondition, 2 verification,
  3 audit, 4 push). Replayable for backfills.

### Fixed

- `Sojourn/Info.plist` had `CFBundleShortVersionString` /
  `CFBundleVersion` hardcoded at `0.1.0` / `1` since initial scaffold.
  Replaced with `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`
  Xcode build-setting substitution; values now flow from `project.yml`.
- `notarize.yml` "Publish Homebrew cask update" step previously
  invoked the deleted `scripts/publish-homebrew-cask.sh`. Recreated it
  per the design below.
- `brew audit [path]` was disabled in Homebrew 5.x — replaced with
  `brew style ./Casks/sojourn.rb` for the in-repo template's CI check.
- In-repo `Casks/sojourn.rb` template's `verified:` parameter dropped
  (URL domain matched homepage — `brew audit` rejected it).

### Changed

- `notarize.yml` Publish step is now direct-push to tap main (no PR).
  Council 2026-05-01-notarize-publish-direct-push deliberated and
  re-voted 5/5 APPROVE-WITH-CONDITIONS after the bump-cask-pr hybrid
  was blocked by the fine-grained PAT lacking `Pull requests: write`.
  Implementation safeguards: tag-format guard, token scrub via
  `git remote set-url` post-clone, ephemeral push-only URL-userinfo
  token (`https://x-access-token:${TAP_TOKEN}@…` for one push command,
  not `.git/config`), `::add-mask::` on the PAT, post-edit positive
  + negative grep verification of `version` + `sha256` lines, online
  audit via `brew audit --cask --online`, `gtimeout 180/30` wrappers,
  `git ls-remote` push-landed verification.
- Workflow installs `coreutils` for `gtimeout` (macOS doesn't ship
  GNU `timeout`).

### Locked decisions (carried into v0.3)

(Details in v0.3-plan.md §"Hard decisions".)

- Containers detection priority: Docker > OrbStack > Apple `container`
  > Lima > Colima.
- mas Touch-ID: privileged helper at
  `/Library/PrivilegedHelperTools/` via `SMAppService`.
- Sparkle delta updates: ship in v0.3.0.
- Multi-machine conflict UX: refuse-and-show-diff.
- `repro-drift` issue template: lives in user's data/dotfiles repo;
  Sojourn ships reference template only at
  `.github/ISSUE_TEMPLATE/repro-drift.md`.
- Cask `caveats` block: instructs `brew uninstall chezmoi mas` on
  cask uninstall (formula deps don't cascade).
- JobRunner timeout: install/upgrade exempt; advisory 30s; snapshot 600s.
- v0.1 packages.toml migration: skipped (alpha had zero users).

### Notes

- Sparkle EdDSA key vault path corrected to
  `op://Bizarre-Industries/sojourn-sparkle-eddsa` (ADR-0020 amended).
- ADR-0022 flip-condition #2 tracking surface re-anchored to user's
  data/dotfiles repo (drift is observed there).
- v1.0.0 + v0.2.1–v0.2.7 GitHub Release artifacts deleted (failed
  iteration attempts; consolidated under single v0.2.0 tag).
- Follow-up issue #5: revisit PAT scope at v0.3 PAT rotation; adding
  `Pull requests: write` to the PAT would unblock the upstream-tooling
  bump-cask-pr hybrid.

## [v1.0-cosmetic-preview, withdrawn] — 2026-05-01

> **Withdrawn 2026-05-01.** Tag `v1.0.0` deleted from local + remote.
> This release shipped the visual design surface (22 panes, aurora
> shell, AccentColor, MenuBarExtra, XCUITest scaffolding, VoiceOver
> labels) but did **not** execute the v0.2 architectural pivot —
> `MPMService`, `Sojourn/Backends/`, `LiquidGlass.swift`, the 22-pane
> sidebar, and the macOS 14 deployment floor were all untouched. The
> SHA `cd84792` remains in `git log` for archaeology; the tag and the
> notion of a "v1.0 release" are gone. v0.2 reboots architecture on
> top of this work, salvaging compatible bits and replacing the rest.
> The GitHub Release artifact (`Sojourn.dmg`) at v1.0.0 is preserved
> with a "superseded — cosmetic preview" notice.

### Added — Wave A · Design surface

- **Design handoff bundled into repo** at
  `docs/design/handoff/sojourn-design.tgz` plus
  `docs/design/README.md`. Tarball contains 23 SwiftUI artboards
  across 8 sections, 4 variable TTFs (Unbounded / BigShouldersStencil
  / HankenGrotesk / JetBrainsMono), and 2 chat transcripts capturing
  intent ("Carry leads · Sync demoted", 5-mode app icon, light-mode
  lime readability rule).
- **Authentic Tahoe Liquid Glass shell** per
  `liquid-glass.css:8-198`:
  - `GlassWallpaper` rewritten as 5 saturated radial blooms (lime /
    pink / amber / blue / purple) over a deep void gradient with
    star-dust speckle. Replaces the earlier 3-blurred-circles
    placeholder so the glass material has something to refract.
  - `MainWindowView` restructured into ZStack(wallpaper,
    HStack(sidebar-tile, content-tile)). Sidebar and content float as
    separate `ultraThinMaterial` tiles with 14-point continuous
    radius and 0.5pt hairline overlay — Tahoe floating-tile spec.
- **`AccentColor.colorset`** at lime `#C6FF24` re-enables
  `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` in `project.yml`.
  System controls (`.tint()`, `Color.accentColor`) now resolve to the
  brand lime.
- **Carry panes** rebuilt per `carry.jsx` + `screens.jsx:111-428`:
  - **OverviewPane** = `CarryOverviewScreen` end-to-end. Stencil
    hero ("PACKAGES. DOTFILES. PREFS."), three carry-surface cards
    (Packages tier table A–E, Dotfiles drift list, Prefs 4-layer
    matrix), the carry-motion card with push/pull buttons + machine
    badges, scheduler card with progress bar and next-run prediction,
    "CATCH THE STARS" callout. Reads `store.managers` for live
    package + outdated counts.
  - **PackagesPane** = three-column layout: midlist (8 managers with
    2-letter glyph + tier + outdated count), detail with cross-manager
    outdated table, per-machine gating code block, streaming-job log
    card.
  - **DotfilesPane** = midlist of 32 managed files with M/A/clean
    glyphs + detail with diff hunks (rendered with line numbers, +/−
    markers, success/danger background tints), per-machine override
    card, ownership registry card, chezmoi command cheatsheet.
  - **PreferencesPane** = midlist of 18 domains (lock icon for
    sandboxed) + detail with iTerm2 plist diff, quit-and-relaunch
    callout, 4-layer model card, FDA canary callout.
- **Sync panes** rebuilt per `screens.jsx:430-569` + `extras.jsx`:
  - **MachinesPane** = three machine cards with model / OS / package
    count / writer badge, plus repo-tree code block matching
    `docs/reference/repo-layout-user.md`.
  - **HistoryPane** = vertical timeline with circular nodes (lime for
    push, warn for conflict, mute otherwise), sha + badge + message +
    machine + diff stat + snapshot link, rollback button per row.
  - **ConflictsPane** = 6-shape grid (text edit / packages.toml /
    chezmoi template / plist / rename × edit / delete × edit) plus
    snapshot-guarantee code block.
  - **OnboardPane** = remote + age cards, 7-step rail (probe → remote
    → machine ID → age identity → writer adds → pull → ready),
    cooperative-lock callout.
- **Hygiene panes** rebuilt per `screens.jsx:571-818`:
  - **SecretsPane** = 4-stat strip, full scan log block with
    timestamp coloring, 5-second-lockout callout, bundled-binary card.
  - **CleanupPane** = orphan candidates table (checkbox / path / size
    / owner-missing-reason / class badge / last-touched / action),
    APFS-atime-warning danger callout.
- **App panes** rebuilt per `extras.jsx:138-270`:
  - **DiagnosticsPane** = 6 OSLog category cards, live subprocess
    tail, redaction toggle wired to `Diagnostics/Redactor.swift`,
    crash-reports note, full 9-tool ToolMatrix (xcode-select / git /
    brew / mpm / chezmoi / gitleaks / age / npm / pnpm) with
    bundled-vs-system labeling.
- **Power surfaces — 10 new sidebar entries** in a `power` section,
  each visually-rich stub backed by a real service in
  `Sojourn/UI/Panes/Power/PowerSurfaces.swift`:
  - `JobInspectorPane` — JobRunner / LogBuffer / ANSIParser surface
    with 5 most-recent jobs.
  - `ScheduleInspectorPane` — `NSBackgroundActivityScheduler` two
    tasks (refresh-outdated / refresh-advisories) with progress bars
    + skip log.
  - `AgeKeysPane` — local identity, recipient list, rotation guide.
  - `ChezmoiTemplatesPane` — 5 commands cheatsheet, `chezmoi data`
    JSON, `.chezmoiignore` boilerplate.
  - `GitleaksRulesPane` — 142 builtin patterns with severity badges,
    allowlist TOML.
  - `AuthorizationPane` — FDA canary probe result, brew installer
    `Authorization.framework` flow.
  - `ManagerDetailPane` — Cargo as the per-manager template (raw mpm
    JSON, pin syntax, advisory bypass).
  - `BackupsPane` — 5-recent backup index with restore action,
    rollback-the-rollback callout.
  - `DefaultsDiscoverPane` — record-session model documented;
    deferred to v1.1 per impl-plan §1.5.
  - `RepoSetupPane` — remote URL + signing toggles + commit message
    template.

### Added — Wave D · Release

- `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 100`.

### Verification

- `xcodegen generate` clean.
- `xcodebuild -scheme Sojourn -destination 'platform=macOS,arch=arm64' build`
  → `** BUILD SUCCEEDED **` on macOS 14.0+ deployment target with
  Swift 6.1 strict concurrency.
- `swift build` clean (UI excluded from SPM library target — Xcode
  compiles UI exclusively, by design per `Package.swift:52-57`).

## [0.1.0] — 2026-04-30

### Added

- **Audit-driven module wiring**:
  - `BackendRegistry` actor + `MPMPackageBackend` adapter wired into
    `AppStore.live()` (audit §3.2.5, ADR-0010 promoted).
  - `HistoryDB` SQLite-backed history log replacing
    `Settings.history` (legacy mirror retained for v0.1 backwards
    compat; removed in v0.2.0). Audit §3.1.6 / §3.3.1.
  - `BootstrapCoordinator` + `ToolProbe` + `ToolInstaller` wired
    alongside the legacy `BootstrapService`. Audit §3.1.3.
- **Sync improvements**:
  - `chezmoi merge` invoked for text dotfiles in the pull path before
    `apply` (audit §2.2.3). Binaries / plists keep `apply --force`.
    `SyncCoordinator.textMergeTargets(fromStatus:)` parser + tests.
- **Settings**:
  - `Settings.githubClientID` field for BYO GitHub OAuth client_id.
    Sojourn-owned default ships in v0.1.1; v0.1.0 users register
    their own at <https://github.com/settings/developers>.
- **Replan-on-ship Claude hooks**: `.claude/settings.json` +
  `.claude/hooks/{replan-on-ship,mark-replanned}.sh`. SessionStart +
  Stop hooks compare `git tag -l 'v*'` against
  `.claude/.last-shipped-tag` (per-clone, gitignored) and inject a
  replan instruction when a new tag is found. Documented in
  `docs/process/release.md` "Replan-on-ship hook" + `AGENTS.md`.
- **New tests**: `BackendRegistryTests`, `HistoryDBTests`,
  `RedactorTests`, `ToolProbeTests`, `KeychainBrokerTests`,
  `SyncMergeTargetTests`. swift test now runs 81 tests in 28 suites.
- Phase 1 core infra: `SubprocessRunner`, `JobRunner`, `LogBuffer`,
  `ANSIParser`, `ToolLocator`.
- Phase 2 models + persistence: `AutoUpdateTier`, `Conflict`,
  `DotfileOwner`, `HistoryEntry`, `MachineMetadata`, `OrphanCandidate`,
  `PreferenceDomain`, `Snapshot`. `AppSupportPaths`, `BackupsDirectory`,
  `DeletionsDB` (SQLite), `SettingsStore`, `SojournFileCodec` (TOML
  subset).
- Phase 3 subprocess service actors: `GitService`, `MPMService`,
  `ChezmoiService`, `PrefService`, `SecretScanService`, `BrewService`,
  `BootstrapService`, `GitHubDeviceAuth`.
- Phase 4 sync coordinator + pre-op snapshot + cooldown gate + OSV
  advisory bypass + `NSBackgroundActivityScheduler` refresh.
- Phase 5 `CleanupService` + bundled `dotfile_owners.toml` (42
  entries) + `gitleaks.toml` + seed `applications/` entry.
- Phase 6 full SwiftUI UI: sidebar + 6 panes + PushPullBar +
  BootstrapView + ConflictResolutionView + SecretFindingsModal (5s
  lockout) + MenuBarRootView + 4-tab Settings scene.
- Phase 7 release pipeline hardening: SHA256-verified
  download-bundled-bins, real `publish-homebrew-cask.sh`,
  Mackup→Sojourn `update-registry.py`.
- Phase 8 docs: `SUPPORTED_MANAGERS`, `CONFLICTS`, `PREFS_DOMAINS`,
  `RELEASE`, `FUTURE`; `ARCHITECTURE.md` §17 Testing + §18 Observability.
- Phase 9 tooling: `.swift-format`, `.swiftlint.yml`.
- **Audit-driven docs restructure (Diátaxis)** — phases 0–12 of the
  docs rework now shipped:
  - Tree skeleton (`start/`, `how-to/`, `reference/`, `explain/` +
    `decisions/`, `process/`, `design/`, `assets/`).
  - 14 ADRs at `docs/decisions/`.
  - `ARCHITECTURE.md` split into 14 destinations; legacy preserved
    at `docs/process/audit-2026-04.md` for `git log --follow`.
  - `SUPPORTED_MANAGERS.md` split into 18 per-manager pages under
    `docs/reference/package-managers/` + `index.md`.
  - 5 net-new audit reference docs (externals, secret-brokers,
    ssh-config, extra-config, plugin-protocol).
  - **Phase 7**: root `SECURITY.md` + `CODE_OF_CONDUCT.md` +
    `docs/explain/threat-model.md` substantive split.
  - **Phase 7.5**: strict proposal §3 naming applied — 9 renames
    via `git mv` (managers/ → package-managers/, preference-domains
    → pref-domains, bootstrap-flow → explain/bootstrap-state-machine,
    observability → explain/observability, competitive-landscape
    → why-sojourn, future-work → process/future, THIRDPARTY.md →
    docs/reference/third-party.md with 1-line root pointer); new
    `docs/reference/chezmoi-features.md` feature-surface index.
  - **Phase 8**: 10 net-new explain pages (why-sojourn,
    design-philosophy, trade-offs, ipc-not-linking, tier-model,
    cooperative-locking, threat-model, carry-vs-sync,
    bootstrap-state-machine, observability).
  - **Phase 9**: 9 net-new reference pages (6 file-formats specs
    `packages-toml`, `machines-toml`, `active-toml`, `version-toml`,
    `deletions-db`, `history-db`; plus `settings`,
    `keyboard-shortcuts`, `cli` placeholders).
  - **Phase 10**: 27 net-new how-to guides across `secrets/` (4),
    `dotfiles/` (7), `sync/` (4), `packages/` (5),
    `preferences/` (3), `diagnostics/` (2), `development/` (2 new).
  - **Phase 11**: 4 net-new tutorials in `start/` (install,
    first-push, second-machine, recover-from-loss).
  - **Phase 12**: audit coverage map appended to
    `process/audit-2026-04.md` linking every audit ID to its
    closing doc URL.
  - `redirects.toml` records every move with sunset version
    (`v0.3` for most, `v0.4` for `ARCHITECTURE.md`).
  - All 7 docs-rework `process/open-questions.md` §11 sub-questions
    closed; `AGENTS.md` ratified as canonical entry.
  - Total: 106 files, +5514 / −630 LOC.

  See `docs/process/audit-2026-04.md` for the audit, `docs/process/implementation-plan.md`
  for code-side sequencing, and `docs/redirects.toml` for the
  rename log.

### Planned (post-v1)

- Phase 10 backend protocol layer (`PackageBackend`, `DotfileBackend`,
  `PrefBackend`, `SecretBroker`, `BackendRegistry`).
- Phase 11 module restructure (`Models/`, `Policy/`, `Diagnostics/`,
  `Secrets/`, `Plugins/`; History → SQLite).
- Phase 12 mpm + chezmoi feature gap (sbom, externals, merge,
  unmanaged, forget, doctor, state, update).
- Phase 13 native brew/cask/mas + brew taps, brew services,
  LaunchAgents, Login Items, tool version managers.
- Phase 14 plugin host + secret broker abstraction (1Password
  primary, age fallback).

### Fixed

- N/A (pre-release).
- Audit drift items §1.1 (Models/ in module tree), §1.2 (Cork license),
  §1.3 (cask cooldown reconciled to 7d).

### Security

- Every auto-commit scans via bundled gitleaks. High-confidence provider
  keys (AWS, GitHub PAT, OpenAI, Stripe, Anthropic, Slack) block the
  commit for 5 seconds in the UI per [SECURITY.md](SECURITY.md) +
  `docs/explain/threat-model.md` (Phase 8).
- Supply-chain cooldown tiers gate auto-updates per
  `docs/reference/cooldown-policy.md`; Tier E (`npm`) never
  auto-updates silently.
