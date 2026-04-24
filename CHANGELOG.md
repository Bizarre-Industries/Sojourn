# Changelog

All notable changes to Sojourn. Follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[SemVer](https://semver.org/).

## [Unreleased]

### Added

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

### Fixed

- N/A (pre-release).

### Security

- Every auto-commit scans via bundled gitleaks. High-confidence provider
  keys (AWS, GitHub PAT, OpenAI, Stripe, Anthropic, Slack) block the
  commit for 5 seconds in the UI per `docs/SECURITY.md`.
- Supply-chain cooldown tiers gate auto-updates; Tier E (`npm`) never
  auto-updates silently.

## [0.1.0] — TBD

Initial notarized DMG ship per [docs/RELEASE.md](docs/RELEASE.md).
