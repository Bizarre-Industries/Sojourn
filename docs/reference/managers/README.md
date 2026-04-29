# Package managers — coverage matrix

Sojourn delegates to `mpm` (meta-package-manager) for managers it covers.
For unsupported managers Sojourn ships a parallel `Service` actor or relies
on the [plugin protocol](../plugin-protocol.md). For tool-version managers,
see audit §2.4.8 — synced as dotfile-classified config files, not service
actors.

Per-manager detail lives in this directory; this page is the matrix.

## Matrix

| Manager                   | Backend                                                                       | Tier                  | Binary path                                      | Notes                                                |
| ------------------------- | ----------------------------------------------------------------------------- | --------------------- | ------------------------------------------------ | ---------------------------------------------------- |
| [`brew`](brew.md)         | mpm v0.1 → native v1.x ([0010](../../decisions/0010-native-brew-keep-mpm.md)) | B (auto, 7d)          | `/opt/homebrew/bin/brew` + `/usr/local/bin/brew` | Primary. Apple-Silicon path first.                   |
| [`cask`](cask.md)         | mpm v0.1 → native v1.x                                                        | C (prompt, 7d)        | via brew                                         | Runs installer scripts — prompt.                     |
| [`mas`](mas.md)           | mpm v0.1 → native v1.x                                                        | A (auto, 0d)          | `/usr/local/bin/mas`                             | Apple reviews; silent auto-update ok.                |
| [`pip`](pip.md)           | mpm                                                                           | D (prompt, 7d)        | per-interpreter                                  | Global interpreter.                                  |
| [`pipx`](pipx.md)         | mpm                                                                           | D (prompt, 7d)        | `~/.local/bin/pipx`                              | App-isolated venvs.                                  |
| [`uvx`](uvx.md)           | mpm                                                                           | D (prompt, 7d)        | `~/.local/bin/uvx`                               | uv tool.                                             |
| [`npm`](npm.md)           | mpm                                                                           | E (never silent, 14d) | `~/.npm-global/bin/npm`                          | Runs preinstall/postinstall — user must approve.     |
| [`yarn`](yarn.md)         | mpm                                                                           | D (prompt, 7d)        | `~/.yarn/bin/yarn`                               | Classic + Berry.                                     |
| [`cargo`](cargo.md)       | mpm                                                                           | B (auto, 7d)          | `~/.cargo/bin/cargo`                             | Curated crates.io.                                   |
| [`gem`](gem.md)           | mpm                                                                           | D (prompt, 7d)        | `~/.gem/bin/gem`                                 | Global interpreter.                                  |
| [`composer`](composer.md) | mpm                                                                           | D (prompt, 7d)        | `~/.composer/vendor/bin/composer`                | Global packages.                                     |
| [`vscode`](vscode.md)     | mpm                                                                           | C (prompt, 7d)        | extension CLI                                    | Extensions; some run setup.                          |
| [`pnpm`](pnpm.md)         | unsupported (deferred)                                                        | E                     | `~/.pnpm/bin/pnpm`                               | Plugin protocol target.                              |
| [`asdf`](asdf.md)         | dotfile sync                                                                  | n/a                   | `~/.asdf/bin/asdf`                               | Tool version manager — sync config, tool reconciles. |
| [`mise`](mise.md)         | dotfile sync (+ reference plugin)                                             | n/a                   | `~/.local/bin/mise`                              | First reference plugin.                              |
| [`rustup`](rustup.md)     | dotfile sync                                                                  | n/a                   | `~/.cargo/bin/rustup`                            | `~/.rustup/settings.toml`.                           |
| [`sdkman`](sdkman.md)     | dotfile sync                                                                  | n/a                   | `~/.sdkman/bin/sdkman-init.sh`                   | `~/.sdkman/etc/config`.                              |
| [`volta`](volta.md)       | dotfile sync                                                                  | n/a                   | `~/.volta/bin/volta`                             | `~/.volta/`.                                         |

## Tier definitions

See [reference/cooldown-policy.md](../cooldown-policy.md) "Per-ecosystem
tiers". Summary:

- **A** — 0 day, fully auto (`mas`).
- **B** — 7 day, fully auto (curated, small maintainer set).
- **C** — 7 day, user prompt (casks, pinned project deps).
- **D** — 7 day, user prompt (global interpreter deps).
- **E** — 14 day, user must approve each version (global npm; ran scripts).

## Adding a manager

If mpm covers it: add to the list of managers `MPMService` fans out to. No
new code.

If mpm does not cover it: create a parallel service actor or write a
plugin. See [how-to/development/add-package-manager.md](../../how-to/development/add-package-manager.md).
