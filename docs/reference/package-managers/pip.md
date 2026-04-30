# pip

Python package installer. Backend: `mpm`. Tier **D** (prompt, 7d). mpm
absorbs interpreter resolution, `--user` / `--break-system-packages`
semantics, and virtualenv detection.

## Binary

Per-interpreter (`python3 -m pip`). Hardcoded interpreter candidates:
`/opt/homebrew/bin/python3`, `/usr/local/bin/python3`, `/usr/bin/python3`.

## Key invocations

- `python3 -m pip list --format=json` — installed list.
- `python3 -m pip list --outdated --format=json` — outdated.
- `python3 -m pip install <pkg>` — install.

## Known issues

- mpm's `--pip` flag does not implement search; `mpm search` errors per
  manager are normal (see [reference/backends/mpm.md](../backends/mpm.md)).
- Multiple interpreters require disambiguation; PURL specifiers
  (`pkg:pypi/<name>`) per audit §2.1.2 land in implementation-plan
  phase 12.
- `--break-system-packages` required on macOS Homebrew Python 3.11+
  installed via Homebrew; mpm sets this when invoking the Homebrew
  interpreter.
