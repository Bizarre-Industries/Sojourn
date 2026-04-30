# Add a chezmoi run script

## Goal

Glue chezmoi to mpm (or arbitrary tooling) by adding a `run_*` script
that fires on apply — typically `run_onchange_before_install-packages.sh.tmpl`
to re-install packages whenever `packages.toml` changes.

## Prereqs

- Sojourn first run completed.
- Familiarity with chezmoi run-script lifecycle (`run_once_`,
  `run_onchange_`, `run_after_`).

## Steps

1. **Decide the lifecycle**:

   | Prefix | Fires when |
   |---|---|
   | `run_once_` | First apply on this Mac (state-cached) |
   | `run_onchange_` | Whenever the script body's hash changes |
   | `run_after_` | After every apply |
   | `run_before_` | Before every apply |

2. **Open Dotfiles pane → New script**.
3. Sojourn drops a stub at `<source>/run_onchange_before_install-packages.sh.tmpl`:

   ```bash
   #!/bin/sh
   # Hash: {{ include "packages.toml" | sha256sum }}
   # Run mpm restore when packages.toml changes.

   set -e

   {{ if .chezmoi.os | eq "darwin" -}}
       /usr/local/bin/mpm restore "{{ .chezmoi.workingTreeAbsPath }}/packages.toml"
   {{- end }}
   ```

   The `Hash:` comment ensures the script body changes when
   `packages.toml` changes; `run_onchange_` re-fires.
4. **Preview render** to confirm the rendered shell is what you
   intend.
5. **Save and apply**. The first apply on this Mac runs the script.

## Verification

- `chezmoi state get-bucket --bucket scriptState` shows the script's
  state hash.
- `packages.toml` changes trigger a re-run on next apply.
- The script's exit code is reported in the History pane.

## Troubleshooting

- **"Script doesn't re-fire after `packages.toml` change"** — the
  `Hash:` comment must include the file you want to watch. Verify
  with `chezmoi execute-template --file run_onchange_*.tmpl`.
- **"Script fires but mpm not found"** — `PATH` inside chezmoi-run is
  the user's login `PATH`, not Sojourn's app `PATH`. Use absolute
  paths.
- **"Want to skip on a specific Mac"** — guard with chezmoi data:
  `{{ if not (eq .chezmoi.hostname "skip-me") -}}` ... `{{- end }}`.

## See also

- [reference/chezmoi-features.md](../../reference/chezmoi-features.md)
  — full run-script lifecycle table.
- [process/audit-2026-04.md §2.2.2](../../process/audit-2026-04.md#22-chezmoi-features-not-surfaced)
  — original gap.
- [reference/backends/chezmoi.md](../../reference/backends/chezmoi.md).
