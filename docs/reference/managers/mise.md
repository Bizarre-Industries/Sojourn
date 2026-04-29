# mise

Modern asdf-style tool version manager
([jdx/mise](https://github.com/jdx/mise)). **Reference plugin** for the
Sojourn plugin protocol per ADR-0013.

## Files synced (dotfile mode)

- `~/.config/mise/config.toml` — global mise config + tool list.
- `~/.tool-versions` — asdf-compatible pin file (mise reads it).

## Plugin mode (v1.x)

`mise.sojourn-plugin` validates the plugin protocol per
[../plugin-protocol.md](../plugin-protocol.md). Surfaces:

- `mise ls --json` → `installed`
- `mise outdated --json` → `outdated`
- `mise install <tool>` → `install`

Tier in plugin manifest: **C** (prompt, 7d) by default.

## Why mise first

Cleanest JSON CLI of any tool-version manager. If the plugin protocol
works for mise, it works for everything else.
