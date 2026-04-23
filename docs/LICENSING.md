# Licensing — Sojourn

Sojourn is **GPL-3.0-or-later**. See [/LICENSE](../LICENSE) for the full text.

## The IPC-not-linking invariant

Sojourn invokes `mpm`, `chezmoi`, `git`, `brew`, `gitleaks`, `age`, and `defaults` as **separate processes**. It communicates with them via:

- Command-line arguments (argv).
- Structured output on stdout/stderr (JSON, TOML, or plaintext).
- Exit codes.

Sojourn does **not**:

- Link any of the above as libraries (no `dlopen`, no static archive, no shared address space).
- Embed their source code into the app bundle.
- Run them as threads inside the Sojourn process.

This is the FSF-recognized arm's-length interaction described in the GPL FAQ under "mere aggregation" and the pipes/subprocess discussion. It does not trigger GPL combined-work obligations, which is why Sojourn (GPL-3.0-or-later) can legally invoke `mpm` (GPL-2.0-only) without license compatibility problems.

Architecturally, the invariant is enforced by `SubprocessRunner` (see [/Sojourn/Services/SubprocessRunner.swift](../Sojourn/Services/SubprocessRunner.swift)) and by the ban in [/CLAUDE.md](../CLAUDE.md) on adding FFI wrappers, `libgit2` bindings, or Swift packages that embed these tools' code.

## Why GPL-3.0-or-later

Full rationale lives in [ARCHITECTURE.md §13](ARCHITECTURE.md#13-licensing-decision). Summary:

- **Not AGPL-3.0.** Sojourn is a desktop app, not a network service. AGPL-3.0 would also block any future decision to ever link `mpm` as a library, because AGPL-3.0 is incompatible with GPL-2.0-only.
- **Not GPL-2.0-or-later.** Lacks GPL-3's anti-tivoization and patent-retaliation clauses that matter for a signed, notarized macOS binary.
- **Not MPL-2.0.** Sojourn is a shipping app, not a library primarily meant for proprietary integration.
- **GPL-3.0-or-later.** Clearest copyleft expectations, compatible with the rest of the stack (Homebrew MIT/BSD, chezmoi MIT, gitleaks MIT, age MIT).

## Third-party components

### Bundled with the app

All code in `Sojourn/Resources/bin/` ships as separately-licensed binaries re-signed under Sojourn's Developer ID. Their source is available upstream.

| Binary | Upstream | License | Purpose |
|---|---|---|---|
| `gitleaks` | https://github.com/gitleaks/gitleaks | MIT | Pre-commit secret scanning. |
| `age` | https://github.com/FiloSottile/age | MIT | External age backend for chezmoi's passphrase/SSH modes. |

### Invoked but not bundled

Discovered or installed on the user's system via the bootstrap flow (see [BOOTSTRAP.md](BOOTSTRAP.md)):

| Tool | Upstream | License | Role |
|---|---|---|---|
| `mpm` (meta-package-manager) | https://github.com/kdeldycke/meta-package-manager | GPL-2.0-only | Unified package-manager wrapper. |
| `chezmoi` | https://github.com/twpayne/chezmoi | MIT | Dotfile templating and apply. |
| `git` | https://git-scm.com | GPL-2.0 | VCS operations; provided by Xcode CLT. |
| `brew` (Homebrew) | https://github.com/Homebrew/brew | BSD-2-Clause | Primary package manager; installer for `mpm`, `chezmoi`, `age`. |
| `defaults`, `plutil`, `killall`, `xattr` | Apple | Proprietary | System CLIs for plist round-trip and file attributes. |

### Data files

| Path | Source | License | Status |
|---|---|---|---|
| `Sojourn/Resources/data/applications/*.toml` | Derived from [lra/mackup](https://github.com/lra/mackup)'s `applications/` registry. | GPL-3.0-or-later | Fork, re-classified per [ARCHITECTURE.md §8](ARCHITECTURE.md#8-plist-app-preference-sync-strategy). Upstream credited in each file header. |
| `Sojourn/Resources/data/gitleaks.toml` | Derived from gitleaks default rules. | MIT (upstream) | Locally tuned. |
| `Sojourn/Resources/data/dotfile_owners.toml` | Original to Sojourn. | GPL-3.0-or-later | Hand-curated. |

### Swift packages

Declared in `Package.swift` (when added):

| Package | Upstream | License |
|---|---|---|
| `swift-subprocess` | https://github.com/swiftlang/swift-subprocess | Apache-2.0 |
| `MenuBarExtraAccess` | https://github.com/orchetect/MenuBarExtraAccess | MIT |

No TCA, no SwiftGit2, no libgit2, no SwiftShell. See [/CLAUDE.md](../CLAUDE.md) "Do not do" list.

## Attribution requirements

The app must show, under Help -> Acknowledgements:

- Sojourn's own GPL-3.0-or-later statement and link to source.
- Each third-party component above with its license and upstream URL.
- The Mackup `applications/` attribution for the data registry fork.

The release DMG includes a `THIRDPARTY.md` file assembled from this table on every build.

## Re-licensing optionality

If a future architectural decision removes the `mpm` subprocess dependency (e.g., Sojourn implements the per-manager wrappers directly in Swift), the GPL-2-only constraint lifts. In that world, relicensing upward to AGPL-3.0 (for a hypothetical server component) or laterally to MPL-2.0 (for broader downstream reuse) becomes possible. GPL-3.0-or-later's "or-later" clause is what preserves this option.

If Sojourn ever grows a hosted network component, AGPL-3.0 becomes the right answer for that component specifically.
