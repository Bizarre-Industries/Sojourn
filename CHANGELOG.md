# Changelog

All notable changes to Sojourn. Follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[SemVer](https://semver.org/).

## [Unreleased]

### Planned (post-1.0)

- Bootstrap sheet: full 9-state UI per
  `docs/explain/bootstrap-state-machine.md` (current single-screen
  consent prompt sufficient for ship; richer state-by-state copy in
  v1.1).
- Settings scene 4-tab rebuild (Schedule / Cooldown / Tool locations /
  Diagnostics) per `screens.jsx:672`. Current single-form Settings
  ships in v1.0 as the in-window proxy.
- Architecture artboard surfaced from Help menu per
  `project/architecture.jsx`.
- App icon: 5-mode Sequoia/Tahoe `.icon` bundle (Icon Composer
  authoring required). Current 11-PNG `.appiconset` fallback ships in
  v1.0.
- Phase 12 mpm + chezmoi feature gap: SBOM commit, externals tab,
  unmanaged tab, forget action, doctor in diagnostics bundle, state
  controls.
- Phase 13 native backends: `BrewService`/`CaskService`/`MasService`
  conforming to `PackageBackend`; brew taps + brew services capture;
  LaunchAgents promotion; `SMAppService` Login Items; tool version
  managers (mise/asdf/rustup/sdkman/volta).
- Phase 14 plugin host + secret broker abstraction: keyless cosign
  verification, 1Password → Keychain → age detection ladder,
  reference plugins (mise / gh-extension / krew / helm-plugin).
- Snapshot tests per pane (27 fixture-backed tests).
- XCUITest navigation coverage across all sidebar entries.
- Accessibility audit: VoiceOver labels, light-mode lime-on-white
  legibility fix using `Color.bzrLimeInk` per chat 2 closing message.
- Discover pane (record-session model) per
  `docs/explain/discover-pane.md` — ships in v1.1.
- Bitwarden broker — ships in v1.1+.
- Native CargoService re-evaluation — see
  `docs/process/open-questions.md` §1.

## [1.0.0] — 2026-05-01

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
    at `docs/_legacy_architecture.md` for `git log --follow`.
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
