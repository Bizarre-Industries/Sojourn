# pipx

App-isolated Python tool installer. Backend: `mpm`. Tier **D** (prompt,
7d).

## Binary

`~/.local/bin/pipx` or `/opt/homebrew/bin/pipx` (Homebrew).

## Key invocations

- `pipx list --json` — installed apps + venv path + version.
- `pipx upgrade-all` — upgrade everything (rarely auto-run; user prompt).
- `pipx install <pkg>` — fresh app install in isolated venv.

## Known issues

- pipx venvs live at `~/.local/pipx/venvs/`. Sojourn syncs the manifest
  (which apps), not the venvs (regenerable).
- Switching Python interpreters via `pipx reinstall-all --python <path>`
  is a manual user operation; not auto.
