# Why Sojourn does not symlink preferences

**The brutal truth: symlinking plists is dead.** Mackup's own README ships
the warning. This is not a macOS 14 change alone — it's the combination of
Sonoma's hardened container TCC, more aggressive `cfprefsd` flushing, and
the long-standing fact that `cfprefsd` rewrites plist files via atomic
rename (which replaces symlinks with regular files).

The decision to use `defaults export/import` instead is recorded in
[decisions/0002-no-symlink-preferences.md](../decisions/0002-no-symlink-preferences.md).

## The Mackup wound

Mackup, the incumbent for Mac app-prefs sync, has been **effectively broken
since Monterey** (macOS 12). PR #2085 added a copy-mode fallback, but it is
not a live sync. Last release 0.8.43, March 2025 — low-velocity maintenance.

What goes wrong:

1. User runs `mackup backup`. Mackup creates symlinks from
   `~/Library/Preferences/com.foo.bar.plist` to a file in the user's iCloud
   or Dropbox folder.
2. User edits a preference in the app. The app, or the system, updates the
   plist via `defaults write` or its higher-level wrappers. `cfprefsd`
   flushes its in-memory state by writing to a tmp file and atomically
   renaming over the destination.
3. **The atomic rename replaces the symlink with a regular file.** The
   sync to iCloud/Dropbox is now silently broken; future writes diverge
   between Macs.
4. Worse: on Sonoma+, sandboxed apps' Container preferences live behind
   TCC. Symlinking into them requires Full Disk Access *and* the system
   has more aggressive flushing. The breakage is faster.

## What works instead

`defaults export <domain> <file>` round-trips through `cfprefsd`'s public
API, updates the in-memory cache, and survives sandbox boundaries. The
matching `defaults import` does the reverse. This is the only first-class
Apple-supported path.

The catch: it's a snapshot, not a live sync. Sojourn pays the snapshot cost
on every push/pull. The win is correctness — we never silently desync.

For the four-layer strategy in detail, see
[reference/preferences.md](../reference/preferences.md).
