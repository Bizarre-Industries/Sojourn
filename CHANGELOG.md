# Changelog

All notable changes to Sojourn. Follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[SemVer](https://semver.org/).

## [Unreleased]

### Planned (post-v0.2.0)

(See `docs/process/plans/v0.3-plan.md`.)

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

## [0.2.0-pre] — superseded

### Planned (post-v0.2)

- v0.3: Containers panel (Apple `container` CLI / OrbStack detection),
  mas Touch-ID privileged helper at `/Library/PrivilegedHelperTools/`,
  Sparkle delta updates, multi-machine sync conflict UX polish.
- v1.x: Discover pane (record-session model), Bitwarden secret broker,
  native Cargo re-evaluation per `docs/process/open-questions.md` §1.

## [0.2.0] — 2026-05-01

Tracking `docs/process/plans/v0.2-plan.md` (canonical). v1.0 cosmetic
preview withdrawn (see section below); v0.2 reboots architecture on
top of that work.

### Planned

- **macOS 26.0 Tahoe deployment floor.** Bump in `project.yml`
  (currently `14.0`), `Sojourn/Info.plist`, `Casks/sojourn.rb`,
  `Package.swift`, Sparkle config. Delete all
  `if #available(macOS XX, *)` checks below 26.
- **Single backend: brew bundle.** `BrewBundleService` replaces
  `MPMService` and the entire `Sojourn/Backends/` directory.
  `Brewfile.common` + `Brewfile.<hostname>` layered install.
  `cooldowns.toml` tier mapping (mas tier A through E for cargo/npm/go).
  ADR-0018 supersedes ADR-0010.
- **Nix mode rejected outright.** ADR-0022-rejected captures evidence
  + flip conditions. No `Backend` protocol, no Phase 2 mode, no
  speculative interface.
- **Real `glassEffect()`** on macOS 26+. `Sojourn/UI/Components/LiquidGlass.swift`
  deleted. Aurora wallpaper dropped. `NavigationSplitView` chrome gets
  the glass treatment for free.
- **Sidebar reduced to typed `Pane` enum, 10 cases:** dashboard,
  packages, generations, macosFeatures, preferences, sync, machines,
  advisories, jobs, settings.
- **`Panes.swift` (2479 lines, 14 structs) split** — one struct per
  file under `Sojourn/UI/Panes/`. Mechanical-subagent task.
- **Generations panel** — first-class UI over git-tagged tarball
  snapshots at `~/Library/Application Support/Sojourn/generations/N.tar.zst`.
  Rollback runs `brew bundle install --cleanup --file=<snapshot>` →
  `chezmoi apply` → `defaults import`. ~85% of nix-darwin's atomic
  rollback UX without `/nix`. New `GenerationService` actor.
- **macOS Features panel** — first-class UI over `defaults write` for
  the knobs `nix-darwin`'s `system.defaults` would have wrapped: Touch
  ID for sudo (with re-apply LaunchAgent against `softwareupdate`
  rewrites), dock layout, Finder defaults, trackpad / keyboard repeat,
  screencapture location/format, login window text, hotkey editor for
  `com.apple.symbolichotkeys.plist`. New `MacOSFeaturesService` actor.
- **Cask + CI rewrite.** Create `Casks/sojourn.rb` matching the Cask
  Cookbook (`livecheck`, `uninstall quit:`, `zap trash:`, `verified:`,
  `depends_on macos: ">= :tahoe"`, `depends_on formula: chezmoi, mas`).
  `notarize.yml` adds `Homebrew/actions/setup-homebrew` + `brew audit
  --cask --new --online` + `brew bump-cask-pr` + Sparkle EdDSA sign
  step (private key in 1Password, read via `op`).
- **`scripts/publish-homebrew-cask.sh` deleted** — replaced by `brew
  bump-cask-pr`.
- **`PrefService` extended** — sandboxed Containers paths, FDA TCC
  flow, PlistBuddy escape hatch, 8ta4 fixture corpus, ship
  `preference-domains.json` for offline lookup.
- **`AdvisoryService` rewritten** as `brew vulns` shell-out. Drops the
  92-line no-op. OSV-format JSON parser, 24h cache at
  `~/Library/Caches/Sojourn/advisories.json`. ADR-0021.
- **Docs purge.** Delete 9 UPPERCASE redirect files +
  `_legacy_architecture.md` + 4 pref-domain dups → single canonical
  `docs/reference/preferences.md`. One source per Diátaxis quadrant.
- **ADRs 0018–0022.** 0018 drop mpm; 0019 cask `depends_on`; 0020
  Sparkle + cask hybrid; 0021 brew vulns; 0022-rejected Nix mode.
  Amend 0001 (narrow IPC scope post-mpm) + 0010 (mark superseded).
- **Mas integration** surfaces "Open in App Store" for unowned
  purchases. Touch-ID-gated helper for `mas install`/`mas upgrade`
  (per CVE-2025-43411 sudo requirement on macOS 14.8.2+ / 15.7.2+ /
  26.1+); never blanket sudo.

### Deferred to v0.3

- Containers panel — Apple `container` CLI (macOS 26+) > OrbStack >
  Docker Desktop > Lima > Colima detection ladder. Stub navigation
  entry only in v0.2.
- mas Touch-ID privileged helper hardening (basic
  AuthorizationServices prompt suffices for v0.2).
- Sparkle delta updates (~85% bandwidth saving).
- Multi-machine sync conflict UX polish.

### Deferred to v1.x

- Discover pane (record-session model) per
  `docs/explain/discover-pane.md`.
- Bitwarden secret broker (deferred per ADR-0016).
- Native Cargo re-evaluation per `docs/process/open-questions.md` §1.

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
