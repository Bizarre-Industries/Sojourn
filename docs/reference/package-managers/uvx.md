# uvx

[uv](https://github.com/astral-sh/uv) tool runner — Python tools in
isolated environments managed by uv. Backend: `mpm`. Tier **D** (prompt,
7d).

## Binary

`~/.local/bin/uvx` (when uv is installed via `curl -LsSf https://astral.sh/uv/install.sh`)
or `/opt/homebrew/bin/uvx` (Homebrew).

## Key invocations

- `uv tool list --format json` — installed tools.
- `uv tool upgrade --all` — upgrade.
- `uv tool install <pkg>` — install.

## Known issues

- Newer than `pipx`; mpm support requires mpm 6.x+.
- uv supports configurable cooldown via `--exclude-newer`; matches
  Sojourn's tier policy.
