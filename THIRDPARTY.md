# Sojourn — Third-party components

Sojourn is GPL-3.0-or-later. Full license text in [/LICENSE](LICENSE).

This file inventories every third-party component Sojourn ships with, links
to, or invokes at runtime, per the policy in
[docs/LICENSING.md](docs/LICENSING.md). It is regenerated on each release and
shipped alongside the notarized DMG.

## Bundled binaries (`Sojourn/Resources/bin/`)

Re-signed under Sojourn's Developer ID. Source available at the upstream
repo.

| Binary | Upstream | License | Purpose |
|---|---|---|---|
| `gitleaks` | https://github.com/gitleaks/gitleaks | MIT | Pre-commit secret scanning. |
| `age` | https://github.com/FiloSottile/age | MIT | External backend for chezmoi's passphrase/SSH encryption modes. |

## Invoked (not bundled)

Discovered or installed on the user's system via the bootstrap flow described
in [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md). Sojourn invokes these as separate
processes only (see
[docs/LICENSING.md](docs/LICENSING.md#the-ipc-not-linking-invariant)).

| Tool | Upstream | License | Role |
|---|---|---|---|
| `mpm` (meta-package-manager) | https://github.com/kdeldycke/meta-package-manager | GPL-2.0-only | Unified package-manager wrapper. |
| `chezmoi` | https://github.com/twpayne/chezmoi | MIT | Dotfile templating and apply. |
| `git` | https://git-scm.com | GPL-2.0 | VCS operations; provided by Xcode CLT. |
| `brew` (Homebrew) | https://github.com/Homebrew/brew | BSD-2-Clause | Primary package manager; installer for `mpm`, `chezmoi`, `age`. |
| `defaults`, `plutil`, `killall`, `xattr` | Apple | Proprietary | System CLIs for plist round-trip and file attributes. |

## Data files

| Path | Source | License | Status |
|---|---|---|---|
| `Sojourn/Resources/data/applications/*.toml` | Derived from [lra/mackup](https://github.com/lra/mackup) | GPL-3.0-or-later | Fork, re-classified per [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Mackup credited in each file header. |
| `Sojourn/Resources/data/gitleaks.toml` | Derived from gitleaks defaults | MIT (upstream) | Locally tuned. |
| `Sojourn/Resources/data/dotfile_owners.toml` | Original to Sojourn | GPL-3.0-or-later | Hand-curated. |

## Swift packages

Declared in [Package.swift](Package.swift) and [project.yml](project.yml).
Minor-version pinned per [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

| Package | Upstream | License | Pinned version |
|---|---|---|---|
| `swift-subprocess` | https://github.com/swiftlang/swift-subprocess | Apache-2.0 | 0.4.0 |
| `MenuBarExtraAccess` | https://github.com/orchetect/MenuBarExtraAccess | MIT | 1.0.5 |
| `swift-system` (transitive) | https://github.com/apple/swift-system | Apache-2.0 | 1.6.4 |

## Attribution surface

The app MUST show, under Help → Acknowledgements:

- Sojourn's own GPL-3.0-or-later statement + link to source.
- Each third-party component above with its license and upstream URL.
- The Mackup `applications/` attribution for the data-registry fork.

## Prohibited additions

Per [CLAUDE.md](CLAUDE.md) "Do not do" list:

- **TCA** (`swift-composable-architecture`) — project uses raw `@Observable`.
- **SwiftGit2**, **SwiftGitX**, **ObjectiveGit**, **libgit2** — git is
  subprocess-only.
- **SwiftShell**, **ShellOut** — unmaintained; use `Process` directly.
- Any library that would embed mpm/chezmoi/brew source into the app bundle.
