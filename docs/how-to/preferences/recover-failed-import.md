# Recover from a failed preference import

## Goal

Restore an app's preferences after a `defaults import` either crashed
the app, applied unexpected values, or didn't take effect.

## Prereqs

- A failed import (the History pane shows `defaults import <bundle-id>`
  with a non-zero exit, or the app behaves wrong after pull).
- The pre-op snapshot from
  `~/Library/Application Support/Sojourn/backups/<ts>-prefs/` is still
  retained (default 30 days).

## Steps

### Quick path: restore from snapshot

1. Open Sojourn → Cleanup pane → *Backups*.
2. Filter by *Preferences imports*. Pick the most recent backup before
   the failed import.
3. Click *Restore prefs from this snapshot*. Sojourn:
   - Quits the affected app (with a confirm prompt).
   - Replaces the plist with the backup.
   - Optionally relaunches the app.

### Specific recovery steps

#### App crashes on launch after import

1. Cmd-Q the app immediately (or *Force Quit* if hung).
2. Restore the pre-import plist from backup (above).
3. Relaunch the app to confirm.
4. Investigate the diff in the History pane → *Show import diff* to
   see what specifically changed. Often a key the app no longer
   handles.

#### Wrong values applied

1. Restore the snapshot.
2. On the source Mac (the one that pushed the bad values), check the
   plist exported into `~/.local/share/sojourn/prefs/<bundle-id>.plist.xml`.
3. Edit the XML directly (Preferences Editor or text editor) to
   correct the values.
4. Push the fix.
5. Re-pull on this Mac to apply the corrected version.

#### Import didn't seem to take effect

This is usually `cfprefsd` caching:

1. Quit the app fully.
2. Run `killall cfprefsd` in Terminal (forces preferences daemon
   restart).
3. Relaunch the app. The newly-imported plist takes effect.

If still not applying, check Sojourn's History — the import job
may have logged an error you missed.

## Verification

- The app launches successfully.
- Preferences match the desired state (either the pre-import snapshot
  or the corrected post-fix state).
- The History pane shows a green entry for the recovery operation.

## Troubleshooting

- **"Backup snapshot doesn't exist"** — the snapshot retention
  expired or pre-op snapshotting was disabled. Restore from a peer
  Mac's plist if available, or accept the loss and re-configure the
  app from scratch.
- **"Sandboxed app didn't restore"** — FDA may have been revoked
  between the import and the restore. Re-grant FDA per
  [handle-sandboxed-app.md](handle-sandboxed-app.md).

## See also

- [reference/preferences.md](../../reference/preferences.md)
  — full export/import flow.
- [reference/cleanup.md](../../reference/cleanup.md) — backup
  retention.
- [reference/file-formats/deletions-db.md](../../reference/file-formats/deletions-db.md)
  — deletion / restore audit log.
