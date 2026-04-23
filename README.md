# Sojourn

Carry your Mac setup — apps, packages, shell configs, and app preferences — across machines and across time.

Sojourn is a native macOS 14+ SwiftUI app that unifies package management (`mpm`), dotfile sync (`chezmoi`), and app-preference round-tripping (`defaults`) behind a GUI. Explicit push/pull between machines, git-backed rollback, scheduled package updates with a supply-chain-attack cooldown, and automatic cleanup of dotfile cruft from uninstalled tools.

## Status

**v0.1 design**, pre-alpha. Not yet shippable. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full spec.

## Requirements

- macOS 14 Sonoma or later (Apple Silicon or Intel).
- Xcode 16+ with Swift 6.1+ toolchain for building from source.
- Homebrew (installed on first run if absent).

## Install

Not yet published. Build from source:

```sh
git clone https://github.com/bizarreindustries/sojourn.git
cd sojourn
open Sojourn.xcodeproj   # once the Xcode project is committed
```

## Docs

- [Architecture](docs/ARCHITECTURE.md) — full design, subsystems, invariants.
- [Bootstrap flow](docs/BOOTSTRAP.md) — first-run state machine.
- [Licensing](docs/LICENSING.md) — GPL-3.0-or-later, IPC-not-linking rationale.
- [Security](docs/SECURITY.md) — secret scanning, cooldown, threat model.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CLAUDE.md](CLAUDE.md) for invariants.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
