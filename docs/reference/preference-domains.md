# Preference domains

Sojourn syncs macOS application preferences via
`defaults export <domain> <file>` / `defaults import <domain> <file>`,
round-tripped through `plutil -convert xml1` for readable diffs. This
doc describes the four plist layers Sojourn recognises and how they
map to behaviour.

See also [ARCHITECTURE.md](ARCHITECTURE.md) §8.

## Layer: `user`

**Path example:** `~/Library/Preferences/com.apple.Terminal.plist`.

- Owned by the logged-in user; `defaults read/write` works without
  additional entitlements.
- **Syncable:** yes. Default tier for most apps Mackup covered.
- Sojourn exports these to `prefs/<bundle_id>.plist` (XML) in the sync
  repo.

## Layer: `system`

**Path example:** `/Library/Preferences/com.apple.loginwindow.plist`.

- Owned by root. Sojourn refuses to modify; exposing for display only.
- **Syncable:** no. Changing system-wide prefs requires admin
  elevation Sojourn does not request.

## Layer: `sandboxed`

**Path example:**
`~/Library/Containers/com.apple.weather/Data/Library/Preferences/com.apple.weather.plist`.

- Container-scoped. Sojourn is **not** sandboxed and thus *can* read
  these — but doing so requires the user to grant Full Disk Access.
- **Syncable:** deferred to **v2**. See
  [ARCHITECTURE.md](ARCHITECTURE.md) §15. The FDA prompt and the
  per-app-quit-relaunch dance add complexity the v1 scope skips.

## Layer: `apple-internal`

**Path example:** `com.apple.LaunchServices.secure.codebless`.

- Apple-managed bookkeeping. Opaque to Mackup-style sync.
- **Syncable:** no. Excluded at the registry level.

## Registry layout

Every supported app has a TOML entry at
`Sojourn/Resources/data/applications/<bundle_id>.toml`. Schema:

```toml
[application]
bundle_id  = "com.apple.Terminal"
domain     = "com.apple.Terminal"
layer      = "user"
syncable   = true
display_name = "Terminal"
```

Regenerate the registry from Mackup via:

```sh
scripts/update-registry.py --mackup-ref master \
  --staging-dir staging/mackup \
  --out Sojourn/Resources/data/applications/
```

Review the diff before committing; Mackup classifications occasionally
collapse multiple domains under one app.

## cfprefsd relaunch

On import, Sojourn runs `killall -u $USER cfprefsd` after
`defaults import` so running apps pick up the new values. This kills
only the user's `cfprefsd`; it respawns immediately. Apps with their
own in-memory cache may still need a manual relaunch — the UI surfaces
this as a per-app hint.
