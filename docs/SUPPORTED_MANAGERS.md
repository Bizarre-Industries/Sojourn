# Supported package managers

Sojourn delegates to `mpm` (meta-package-manager) for every manager `mpm`
itself supports. For anything `mpm` does not cover, Sojourn may implement
a parallel `Service` actor (see [CLAUDE.md](../CLAUDE.md) "How to add
support for a new package manager").

## Coverage table

| Manager | Via mpm? | Tier | Binary probe | Config locations | Notes |
|---|---|---|---|---|---|
| `brew` | yes | B (7d auto) | `/opt/homebrew/bin/brew` + `/usr/local/bin/brew` | `~/Library/Caches/Homebrew` | Apple-Silicon path first. |
| `cask` | yes | C (prompt, 7d) | via brew | `~/Library/Caches/Homebrew` | Runs installer scripts — prompt. |
| `mas` | yes | A (0d auto) | `/usr/local/bin/mas` | n/a | Apple reviews; silent auto-update ok. |
| `pip` | yes | D (prompt, 7d) | per-interpreter | `~/.config/pip` | Global interpreter. |
| `pipx` | yes | D | `~/.local/bin/pipx` | `~/.local/pipx` | App-isolated venvs. |
| `uvx` | yes | D | `~/.local/bin/uvx` | project-scoped | uv tool. |
| `npm` | yes | E (never silent, 14d) | `~/.npm-global/bin/npm` | `~/.npmrc` | Ran `preinstall`/`postinstall` — user must approve. |
| `yarn` | yes | D | `~/.yarn/bin/yarn` | `~/.yarnrc.yml` | Classic + Berry. |
| `cargo` | yes | B | `~/.cargo/bin/cargo` | `~/.cargo/config.toml` | Curated crates.io. |
| `gem` | yes | D | `~/.gem/bin/gem` | `~/.gemrc` | Global interpreter. |
| `composer` | yes | D | `~/.composer/vendor/bin/composer` | `~/.composer/composer.json` | Global packages. |
| `vscode` | yes | C | extension CLI | `~/.vscode/extensions` | Often casks run setup scripts. |
| `pnpm` | no (v1 deferred) | E | `~/.pnpm/bin/pnpm` | `~/.pnpmfile.cjs` | See `docs/FUTURE.md`. |
| `asdf` | no (future) | — | `~/.asdf/bin/asdf` | `~/.asdfrc` | Meta-version manager; conflicts with mpm's per-runtime view. |
| `apt` | n/a | — | — | — | Not macOS. |

## Tiers (cooldown + auto-install)

See [SECURITY.md](SECURITY.md#supply-chain-cooldown). Summary:

- **A** — 0 day, fully auto (`mas`: Apple reviews).
- **B** — 7 day, fully auto (curated, small maintainer set).
- **C** — 7 day, user prompt (casks, pinned project deps).
- **D** — 7 day, user prompt (global interpreter deps).
- **E** — 14 day, user must approve each version (global npm; ran scripts).

## Adding a manager not covered by mpm

1. Add a `PackageManager` case in `Sojourn/Models/ManagerSnapshot.swift`.
2. Update `Sojourn/Services/ToolLocator.swift` if the binary lives outside
   the default candidate directories.
3. Create `Sojourn/Services/<Name>Service.swift` parallel to `MPMService`.
   Implement: `installed()`, `outdated()`, `install(pkgs:)`,
   `remove(pkgs:)`, `upgrade(pkgs:)`. Return `ManagerSnapshot` shape.
4. Add fixture-backed tests under `SojournTests/Services/`.
5. Classify tier in `Sojourn/Models/AutoUpdateTier.swift`
   `ManagerTier.defaults`; default to `.c` if unsure.
6. Wire into `AppStore` + UI dispatch in `PackagesPane`.
7. Document here + in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).
8. Add `data/applications/` classification if the manager also has a
   plist domain.
