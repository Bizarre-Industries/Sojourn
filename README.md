# Sojourn

Carry your Mac setup — apps, packages, shell configs, and app preferences
— across machines and across time.

Sojourn is a native macOS 14+ SwiftUI app that unifies package management
(`mpm`), dotfile sync (`chezmoi`), and app-preference round-tripping
(`defaults`) behind a GUI. Explicit push/pull between machines, git-backed
rollback, scheduled package updates with a supply-chain-attack cooldown,
and automatic cleanup of dotfile cruft from uninstalled tools.

## Status

**v0.1 scaffold**, pre-alpha. Not yet shippable as a notarized DMG; the
code landed per the phased implementation in
[docs/process/implementation-plan.md](docs/process/implementation-plan.md)
and every subsystem is fixture-backed tested. See
[docs/reference/architecture.md](docs/reference/architecture.md) for
the full spec.

## Features (v0.1)

- **Bootstrap** first-run wizard that probes, installs, and verifies
  `xcode-select`, `brew` (signed `.pkg`), `mpm`, `chezmoi`.
- **Sync** push/pull against a user-owned git remote, with pre-op tarball
  snapshots (30-day retention) and bundled gitleaks scanning before every
  auto-commit.
- **Packages** via mpm: brew, cask, mas, pip, pipx, uvx, npm, yarn, cargo,
  gem, composer, vscode. Per-manager cooldown tiers (A–E) per
  [docs/reference/cooldown-policy.md](docs/reference/cooldown-policy.md).
- **Dotfiles** via chezmoi with ownership-registry-classified orphan
  cleanup.
- **Preferences** via `defaults export` + `plutil -convert xml1`; no
  `~/Library/Preferences` symlink farms.
- **Menu bar** status + main window with six panes (Packages, Dotfiles,
  Preferences, History, Machines, Cleanup).
- **Diagnostics** exportable log bundle with redacted secrets.

## Requirements

- macOS 14 Sonoma or later (Apple Silicon or Intel).
- Xcode 16+ with Swift 6.1+ toolchain for building from source.
- Homebrew (installed on first run if absent).

## Install

Not yet published to Homebrew. Build from source:

```sh
git clone https://github.com/Bizarre-Industries/Sojourn.git
cd Sojourn
make bootstrap         # brew install xcodegen swiftlint swift-format gitleaks
make generate          # regenerate Sojourn.xcodeproj from project.yml
open Sojourn.xcodeproj
```

Run the test suite:

```sh
make test              # swift test (67+ tests in ~6s)
make xcodebuild        # xcodebuild -scheme Sojourn test
make leaks             # gitleaks dir --config=.gitleaks.toml
```

## Docs

Sojourn's docs follow [Diátaxis](https://diataxis.fr) — start here:
[docs/README.md](docs/README.md).

**Reference** (look up exact facts):

- [Architecture](docs/reference/architecture.md) — top-down system spec.
- [Modules](docs/reference/modules.md) — Sojourn/ directory layout.
- [Bootstrap flow](docs/reference/bootstrap-flow.md) — first-run state machine.
- [Sync model](docs/reference/sync-model.md) — push/pull semantics.
- [Cooldown policy](docs/reference/cooldown-policy.md) — supply-chain tiers.
- [Conflict shapes](docs/reference/conflict-shapes.md) — sync-merge shapes.
- [Preference sync](docs/reference/preference-sync.md) +
  [Preference domains](docs/reference/preference-domains.md) — plist round-trip.
- [Cleanup](docs/reference/cleanup.md) — orphan detection.
- [Licensing](docs/reference/licensing.md) — GPL-3.0-or-later, IPC-not-linking.
- [Testing](docs/reference/testing.md), [Observability](docs/reference/observability.md).
- [Backends](docs/reference/backends/) — mpm, chezmoi, gitleaks, git.
- [Managers](docs/reference/managers/) — per-manager pages + matrix.
- [Externals](docs/reference/externals.md), [SSH config](docs/reference/ssh-config.md),
  [Secret brokers](docs/reference/secret-brokers.md),
  [Extra config](docs/reference/extra-config.md),
  [Plugin protocol](docs/reference/plugin-protocol.md).

**Explain** (understand the why):

- [Why Sojourn](docs/explain/competitive-landscape.md),
  [Risks](docs/explain/risks.md),
  [Why no symlink prefs](docs/explain/why-no-symlink-prefs.md),
  [State management](docs/explain/state-management.md),
  [Future work](docs/explain/future-work.md).

**Decisions** (immutable ADR log):

- [Decisions index](docs/decisions/README.md) — 14 ADRs.

**Process** (contributor/maintainer):

- [Implementation plan](docs/process/implementation-plan.md) — phases 0–14.
- [Audit 2026-04](docs/process/audit-2026-04.md) — gap analysis.
- [Open questions](docs/process/open-questions.md) — deferred to maintainer.
- [Release](docs/process/release.md), [Docs policy](docs/process/DOCS_POLICY.md).

**Security** policy: [SECURITY.md](SECURITY.md) at repo root.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CLAUDE.md](CLAUDE.md) for
invariants (IPC-not-linking, no bundled mpm, fixture-backed tests).

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) and [THIRDPARTY.md](THIRDPARTY.md).
