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
[docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) and every
subsystem is fixture-backed tested. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full spec.

## Features (v0.1)

- **Bootstrap** first-run wizard that probes, installs, and verifies
  `xcode-select`, `brew` (signed `.pkg`), `mpm`, `chezmoi`.
- **Sync** push/pull against a user-owned git remote, with pre-op tarball
  snapshots (30-day retention) and bundled gitleaks scanning before every
  auto-commit.
- **Packages** via mpm: brew, cask, mas, pip, pipx, uvx, npm, yarn, cargo,
  gem, composer, vscode. Per-manager cooldown tiers (A–E) per
  [docs/SECURITY.md](docs/SECURITY.md).
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

- [Architecture](docs/ARCHITECTURE.md) — full design, subsystems, invariants.
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md) — phased delivery.
- [Bootstrap flow](docs/BOOTSTRAP.md) — first-run state machine.
- [Licensing](docs/LICENSING.md) — GPL-3.0-or-later, IPC-not-linking rationale.
- [Security](docs/SECURITY.md) — secret scanning, cooldown, threat model.
- [Supported managers](docs/SUPPORTED_MANAGERS.md) — coverage table + tiers.
- [Conflicts](docs/CONFLICTS.md) — sync-merge shapes.
- [Preference domains](docs/PREFS_DOMAINS.md) — plist layer model.
- [Release runbook](docs/RELEASE.md) — maintainer-only.
- [Future](docs/FUTURE.md) — v2 deferred scope + ideas.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CLAUDE.md](CLAUDE.md) for
invariants (IPC-not-linking, no bundled mpm, fixture-backed tests).

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) and [THIRDPARTY.md](THIRDPARTY.md).
