# Add a package manager Sojourn doesn't natively support

## Goal

Bring a package manager that's not in Sojourn's built-in list (mpm
gap, niche tool, internal company package server) into the sync flow.

## Prereqs

- The package manager has a deterministic install / list / install-from-file
  CLI surface.
- You're comfortable writing a small plugin manifest.

## Two paths

| Path | Effort | Best for |
|---|---|---|
| **`run_*` script glue** | low | Per-Mac install commands embedded in chezmoi |
| **Plugin protocol** | higher | First-class Sojourn integration with status / outdated / restore |

## Steps — `run_*` script glue (low effort)

For a manager like `pnpm` (mpm doesn't cover it as of v6.x):

1. Write a `run_onchange_after_install-pnpm.sh.tmpl`:

   ```bash
   #!/bin/sh
   # Hash: {{ include "pnpm-globals.txt" | sha256sum }}
   set -e
   while read -r pkg; do
     /usr/local/bin/pnpm add -g "$pkg"
   done < {{ .chezmoi.workingTreeAbsPath }}/pnpm-globals.txt
   ```

2. Commit `pnpm-globals.txt` listing the global packages.
3. See [how-to/dotfiles/add-run-script.md](../dotfiles/add-run-script.md)
   for the full lifecycle.

This works but doesn't give Sojourn knowledge of `pnpm` state.
The Packages pane won't show pnpm packages; History won't track
pnpm operations.

## Steps — Plugin protocol (full integration)

Sojourn's plugin protocol ([reference/plugin-protocol.md](../../reference/plugin-protocol.md))
lets you ship a JSON-RPC-over-stdio binary that Sojourn invokes for
`installed`, `outdated`, `install`, etc.

1. **Write the plugin manifest** at `~/.local/share/sojourn/plugins/pnpm/manifest.toml`:

   ```toml
   id      = "pnpm"
   name    = "pnpm (Node)"
   version = "0.1.0"
   binary  = "pnpm-sojourn-plugin"
   protocol = "1"
   tier    = "E"
   ```

2. **Implement the binary**. Sojourn calls it with JSON-RPC on stdio:

   ```json
   {"jsonrpc":"2.0","id":1,"method":"installed","params":{}}
   ```

   Plugin responds with the same shape mpm uses (see
   [reference/plugin-protocol.md](../../reference/plugin-protocol.md)).

3. **Sign the binary** with cosign (per ADR-0013, plugin trust is
   signature-required by default).

4. **Drop into the plugin directory** and restart Sojourn. The
   Plugins pane (Phase 14) shows the plugin loaded.

## Verification

- The Packages pane lists packages from the new manager.
- Outdated check, restore, install all work.
- History logs operations against the plugin.

## Troubleshooting

- **"Plugin not loading"** — Sojourn refuses unsigned plugins by
  default ([decisions/0013-out-of-process-plugins.md](../../decisions/0013-out-of-process-plugins.md)).
  Sign with cosign and place the public key in the trust list.
- **"Manager not detected"** — verify the plugin's `binary` is on
  Sojourn's `PATH`-probe list. Drop in `/usr/local/bin` to be safe.

## See also

- [reference/plugin-protocol.md](../../reference/plugin-protocol.md).
- [decisions/0013-out-of-process-plugins.md](../../decisions/0013-out-of-process-plugins.md).
- [process/audit-2026-04.md §2.7](../../process/audit-2026-04.md#27-plugin-protocol).
