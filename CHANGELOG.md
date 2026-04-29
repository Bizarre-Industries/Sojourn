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
- **Audit-driven docs restructure (Diátaxis)**:
  Phases 0–8 of the docs rework — full Diátaxis tree under `docs/`
  (`start/`, `how-to/`, `reference/`, `explain/` + `decisions/`,
  `process/`, `design/`, `assets/`); 14 ADRs at `docs/decisions/`;
  ARCHITECTURE.md split into 14 destinations preserved at
  `docs/_legacy_architecture.md`; SUPPORTED_MANAGERS.md split into
  18 per-manager pages + index; 5 net-new audit docs (externals,
  secret-brokers, ssh-config, extra-config, plugin-protocol);
  `redirects.toml` tracks every move with sunset version. See
  `docs/process/audit-2026-04.md` for the audit and
  `docs/process/implementation-plan.md` for sequencing.

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

## [0.1.0] — TBD

Initial notarized DMG ship per
[docs/process/release.md](docs/process/release.md).
