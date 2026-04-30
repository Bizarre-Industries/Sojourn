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

## [0.1.0] — TBD

Initial notarized DMG ship per
[docs/process/release.md](docs/process/release.md).
