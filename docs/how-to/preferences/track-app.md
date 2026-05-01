# Track an app's preferences

## Goal

Add an unsandboxed Mac app to Sojourn's preference-sync list so its
plist round-trips between Macs.

## Prereqs

- The app is unsandboxed (most direct-distribution apps; Mac App Store
  apps are sandboxed and need separate handling — see
  [handle-sandboxed-app.md](handle-sandboxed-app.md)).
- The app has been launched at least once on this Mac (so its plist
  exists at `~/Library/Preferences/<bundle-id>.plist`).

## Steps

1. **Open the Preferences pane**.
2. Search for the app by name. Sojourn shows already-tracked apps and
   detected-but-untracked candidates.
3. **Click *Track* on the app**. Sojourn:
   - Reads `~/Library/Preferences/<bundle-id>.plist`.
   - Adds the bundle ID to `prefs.toml` in the data repo:

     ```toml
     [apps]
     "com.sublimetext.4" = { name = "Sublime Text", tier = "auto" }
     ```

   - Exports the current plist as `~/.local/share/sojourn/prefs/<bundle-id>.plist.xml`
     (XML form, diffable).
   - Stages the plist file for commit.
4. **Push**.
5. On peer Macs: pull → Sojourn imports the plist via `defaults
   import` and quits/relaunches the app if it's running.

## Tier classification

| Tier | Behaviour |
|---|---|
| `auto` | Pull + import without prompt |
| `prompt` | Pull preview shows the import, user confirms |
| `review` | User explicitly imports each time via the Preferences pane |

Default is `auto` for tracked apps; user-set per-app in the Preferences
pane.

## Verification

- The app appears in the Preferences pane → *Tracked apps*.
- The plist file lives in `~/.local/share/sojourn/prefs/`.
- A peer Mac, after pulling and importing, has the same preferences.

## Troubleshooting

- **"Plist export fails"** — the app may have its plist held by
  `cfprefsd`. Sojourn calls `defaults read <bundle-id>` first to flush
  cfprefsd; if that fails, quit the app and try again.
- **"Import on peer Mac doesn't take effect"** — `cfprefsd` caches
  preferences for running apps. Sojourn quits the app before importing
  and prompts to relaunch. If you skipped the relaunch, the import
  applied to disk but the running process still uses cached values.
- **"Track button greyed out"** — the app is detected as sandboxed.
  See [handle-sandboxed-app.md](handle-sandboxed-app.md).

## See also

- [reference/preferences.md](../../reference/preferences.md) —
  full list of supported domains + classification.
- [reference/preferences.md](../../reference/preferences.md)
  — the export/import flow.
- [decisions/0002-no-symlink-preferences.md](../../decisions/0002-no-symlink-preferences.md)
  — why `defaults import`, not symlinks.
