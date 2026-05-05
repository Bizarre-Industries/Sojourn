# Reset tool detection

## Goal

Force Sojourn to re-probe for `brew`, `chezmoi`, `git`, `gitleaks`, `age`,
and `defaults`. Useful after installing or moving a tool, or when Sojourn
shows *Tool not found* on a tool you know is installed.

## Prereqs

- Sojourn running.

## Steps

1. **Open Sojourn → Settings → Tools**.
2. Click *Re-probe tools*. Sojourn:
   - Re-runs `ToolLocator` against the candidate paths
     (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.cargo/bin`,
     `~/.local/bin`, `~/go/bin`, `/usr/bin`).
   - Updates the *Tool detection* table.

## Why detection sometimes fails

Sojourn uses **path probing**, not `which`. The reason: the LaunchServices
`PATH` Sojourn inherits is minimal and doesn't include common tool install
locations. `which` would miss `/opt/homebrew/bin/brew` even when Homebrew is
installed.

`ToolLocator` ([AGENTS.md](../../../AGENTS.md) "Paths are probed, not
`which`-ed") iterates a hardcoded candidate list. If a tool is installed to a
non-default location:

1. *Settings → Tools → Add custom path*.
2. Or symlink into one of the standard candidate paths.

## Steps for a custom location

If `chezmoi` is installed at `~/.opt/bin/chezmoi`:

1. Symlink: `ln -s ~/.opt/bin/chezmoi /usr/local/bin/chezmoi` (or the
   equivalent location).
2. Re-probe via Settings → Tools.
3. The *Tool detection* table shows `chezmoi` with the new path.

## Verification

- The *Tool detection* table shows the tool with a green check and the
  resolved path.
- The relevant pane becomes functional.

## Troubleshooting

- **"Re-probe still doesn't find it"** — the binary may not have execute
  permissions for your user. `ls -l <path>` to verify; `chmod +x <path>` if
  needed.
- **"Wrong version detected"** — multiple installs on candidate paths get the
  first one ToolLocator finds in candidate order. Move or remove the unwanted
  install.

## See also

- [reference/architecture.md](../../reference/architecture.md) — ToolLocator
  design.
- [explain/bootstrap-state-machine.md](../../explain/bootstrap-state-machine.md)
  — first-run tool-probe flow.
- [AGENTS.md](../../../AGENTS.md) "Paths are probed, not `which`-ed".
