# Reset tool detection

## Goal

Force Sojourn to re-probe for `mpm`, `chezmoi`, `git`, `brew`, `gitleaks`,
`age`, and `defaults`. Useful after installing or moving a tool, or when
Sojourn shows *Tool not found* on a tool you know is installed.

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
`PATH` Sojourn inherits is minimal and doesn't include common tool
install locations. `which` would miss `/opt/homebrew/bin/mpm` even when
mpm is installed.

`ToolLocator` ([CLAUDE.md](../../../CLAUDE.md) "Paths are probed, not
`which`-ed") iterates a hardcoded candidate list. If a tool is installed
to a non-default location:

1. *Settings → Tools → Add custom path* (Phase 12).
2. Or symlink into one of the standard candidate paths.

## Steps for a custom location

If `mpm` is installed at `~/.opt/bin/mpm`:

1. Symlink: `ln -s ~/.opt/bin/mpm /usr/local/bin/mpm` (or the equivalent
   location).
2. Re-probe via Settings → Tools.
3. The *Tool detection* table shows mpm with the new path.

Alternatively, audit §2.1.5 calls for using `mpm locate` first as a
fallback before the candidate list. Phase 12 ships this; pre-Phase-12
the symlink approach is the workaround.

## Verification

- The *Tool detection* table shows the tool with a green check and
  the resolved path.
- The relevant pane (e.g. Packages for `mpm`) becomes functional.

## Troubleshooting

- **"Re-probe still doesn't find it"** — the binary may not have
  execute permissions for your user. `ls -l <path>` to verify;
  `chmod +x <path>` if needed.
- **"Wrong version detected"** — multiple installs on `PATH` get
  the first one ToolLocator finds in candidate order. Move or
  remove the unwanted install.

## See also

- [reference/architecture.md](../../reference/architecture.md) —
  ToolLocator design.
- [explain/bootstrap-state-machine.md](../../explain/bootstrap-state-machine.md)
  — first-run tool-probe flow.
- [CLAUDE.md](../../../CLAUDE.md) "Paths are probed, not `which`-ed".
- [process/audit-2026-04.md §2.1.5](../../process/audit-2026-04.md#21-mpm-features-not-used)
  — `mpm locate` integration plan.
