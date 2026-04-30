# Export a diagnostics bundle

## Goal

Generate a self-contained diagnostics bundle that includes Sojourn's
recent logs, history, deletion audit, configuration, and tool-detection
state. Use it for support requests or before-/after-issue snapshots.

## Prereqs

- Sojourn running.

## Steps

1. **Open Sojourn → Settings → Diagnostics**.
2. Click *Export diagnostics bundle*. A save dialog opens; pick a path
   (default: `~/Desktop/sojourn-diagnostics-<ts>.zip`).
3. Sojourn assembles the bundle in a tmpdir, then writes the zip.

## What's in the bundle

| File | Source | Notes |
|---|---|---|
| `info.toml` | runtime | macOS version, Sojourn version, bundle id |
| `tool-detection.json` | `ToolLocator` | All probed paths + which were found |
| `chezmoi-doctor.txt` | `chezmoi doctor` | Embeds chezmoi's own diagnostics |
| `mpm-managers.json` | `mpm --table-format json managers` | Manager inventory |
| `system-paths.txt` | `echo $PATH` snapshots | LaunchServices PATH + login PATH |
| `osLog/` | `log stream --predicate 'subsystem == "app.bizarre.sojourn"'` | Last 24h of OSLog |
| `history.db` | `~/Library/Application Support/Sojourn/history.db` | Full SQLite copy |
| `deletions.db` | `~/Library/Application Support/Sojourn/deletions.db` | Full SQLite copy |
| `settings.plist` | `defaults export app.bizarre.sojourn` | Sojourn user prefs |
| `redirects.toml` | repo | For docs reproducibility (debug-builds only) |

## Redaction

By default (Settings → Diagnostics → *Redact paths*), Sojourn:

- Replaces `/Users/<you>/` with `/Users/<USER>/` everywhere.
- Replaces `<your-hostname>` with `<HOSTNAME>`.
- Drops the body of any line OSLog tagged with `private:`
  (`{public}`-only output remains intact).
- Drops Keychain references (no values, ever — Keychain isn't read at
  all).

To disable redaction (for self-debugging only): toggle off before
export. **Don't share unredacted bundles** publicly; they contain
your hostname and home path.

## Verification

- The bundle is a valid zip; unzipping reveals the file list above.
- `info.toml` has the current Sojourn version.
- `osLog/sojourn-<timeslot>.log` lines are timestamped.
- (With redaction on) no instance of your username or hostname.

## Sharing

For Sojourn support / bug reports:

1. Re-verify redaction.
2. Attach the zip to the GitHub issue (or email the maintainer per
   `MAINTAINERS.md` if it contains anything you'd rather not share
   publicly).
3. Include a short description of when the issue happened (timestamp
   helps Sojourn maintainer find the relevant log lines).

## Troubleshooting

- **"Bundle is huge (>100 MB)"** — `osLog/` can be large for
  long-uptime sessions. Reduce the time window in *Settings →
  Diagnostics → Log lookback*.
- **"`chezmoi doctor` fails inside the bundle"** — `chezmoi`
  detection failed. The bundle's `tool-detection.json` will show the
  failure path; that's the diagnostic data point.

## See also

- [explain/observability.md](../../explain/observability.md) —
  OSLog category structure.
- [reference/file-formats/history-db.md](../../reference/file-formats/history-db.md).
- [reference/file-formats/deletions-db.md](../../reference/file-formats/deletions-db.md).
- [process/audit-2026-04.md §5.2.6](../../process/audit-2026-04.md#52-missing-docs)
  — observability gap.
