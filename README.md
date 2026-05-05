# Sojourn

Carry your Mac setup — apps, packages, shell configs, and app preferences
— across machines and across time.

Sojourn is a native macOS 26+ SwiftUI app for brew-native Mac config
management. It uses Brewfile + chezmoi as the declarative source of truth,
wraps system-defaults round-tripping behind a GUI, keeps explicit push/pull
between machines, and records rollback generations before risky changes.
Think "what nix-darwin would be if it didn't make you learn Nix."

## Status

**v0.4 is in active development.** v0.3.0 shipped as a notarized DMG on
2026-05-04; v0.4 is the native UI reset and release-hardening pass. The
active execution plan is
[docs/process/plans/v0.4-plan.md](docs/process/plans/v0.4-plan.md).

## Current direction

- **Bootstrap** first-run wizard that probes, installs, and verifies
  `xcode-select`, Homebrew via signed `.pkg`, `chezmoi`, `git`, `gitleaks`,
  and `age`.
- **Sync** push/pull against a user-owned git remote, with pre-op generation
  snapshots and bundled gitleaks scanning before every auto-commit.
- **Packages** through **brew bundle** as the single backend. No `mpm`, no Nix,
  no speculative `Backend` protocol; ADR-0018 supersedes the old split-backend
  plan.
- **Dotfiles** via chezmoi with ownership-registry-classified orphan cleanup.
- **Preferences** via `defaults export` + `plutil -convert xml1`; no
  `~/Library/Preferences` symlink farms.
- **Native macOS utility UI** with overview, packages, containers,
  generations, macOS features, preferences, sync, machines, advisories, jobs,
  and settings panes.
- **Diagnostics** exportable log bundle with redacted secrets.

## Requirements

- macOS 26.0 Tahoe or later (Apple Silicon or Intel).
- Xcode 26+ / Swift 6.2+ era toolchain for building from source.
- Homebrew (installed on first run if absent).

## Install

Build from source:

```sh
git clone https://github.com/Bizarre-Industries/Sojourn.git
cd Sojourn
make bootstrap         # brew install xcodegen swiftlint swift-format gitleaks
make generate          # regenerate Sojourn.xcodeproj from project.yml
open Sojourn.xcodeproj
```

Run useful local gates:

```sh
make test              # swift test
make xcodebuild        # xcodebuild -scheme Sojourn test
make leaks             # gitleaks dir --config=.gitleaks.toml
make ci-local          # local release-oriented checks
```

## Docs

Sojourn's docs follow [Diátaxis](https://diataxis.fr) — start here:
[docs/README.md](docs/README.md).

**Reference** (look up exact facts):

- [Architecture](docs/reference/architecture.md) — top-down system spec.
- [Modules](docs/reference/modules.md) — Sojourn/ directory layout.
- [Bootstrap flow](docs/explain/bootstrap-state-machine.md) — first-run state machine.
- [Sync model](docs/reference/sync-model.md) — push/pull semantics.
- [Cooldown policy](docs/reference/cooldown-policy.md) — supply-chain tiers.
- [Conflict shapes](docs/reference/conflict-shapes.md) — sync-merge shapes.
- [Preference sync](docs/reference/preferences.md) — plist round-trip.
- [Cleanup](docs/reference/cleanup.md) — orphan detection.
- [Licensing](docs/reference/licensing.md) — GPL-3.0-or-later, IPC-not-linking.
- [Testing](docs/reference/testing.md), [Observability](docs/reference/observability.md).
- [Backends](docs/reference/backends/) — chezmoi, gitleaks, git, and historical mpm notes.
- [Managers](docs/reference/package-managers/) — per-manager pages + matrix.
- [Externals](docs/reference/externals.md), [SSH config](docs/reference/ssh-config.md),
  [Secret brokers](docs/reference/secret-brokers.md),
  [Extra config](docs/reference/extra-config.md),
  [Plugin protocol](docs/reference/plugin-protocol.md).

**Explain** (understand the why):

- [Why Sojourn](docs/explain/why-sojourn.md),
  [Risks](docs/explain/risks.md),
  [Why no symlink prefs](docs/explain/why-no-symlink-prefs.md),
  [State management](docs/explain/state-management.md),
  [Future work](docs/process/future.md).

**Decisions** (immutable ADR log):

- [Decisions index](docs/decisions/README.md) — ADRs 0001–0027.

**Process** (contributor/maintainer):

- [Active v0.4 plan](docs/process/plans/v0.4-plan.md) — current autonomous agent plan.
- [Implementation plan](docs/process/implementation-plan.md) — historical v0.1 → v1 plan.
- [Audit 2026-04](docs/process/audit-2026-04.md) — gap analysis.
- [Open questions](docs/process/open-questions.md) — deferred to maintainer.
- [Release](docs/process/release.md), [Docs policy](docs/process/DOCS_POLICY.md).

**Security** policy: [SECURITY.md](SECURITY.md) at repo root.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) for
invariants (IPC-not-linking, brew bundle as the single backend, no lower-macOS
compatibility gates, fixture-backed tests).

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) and [THIRDPARTY.md](THIRDPARTY.md).
