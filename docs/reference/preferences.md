# Preferences

Canonical reference for how Sojourn syncs macOS application preferences.
Folds the prior `pref-domains.md`, `preference-domains.md`, and
`preference-sync.md` into one Diátaxis-reference page.

> **Audit driver**: tracks
> [process/audit-2026-04.md §1.5](../process/audit-2026-04.md#1-doc-level-inconsistencies)
> (Discover-pane open question) + drives audit §4.1.* preference-pane gaps.

Sojourn round-trips macOS prefs via
`defaults export <domain> <file>` / `defaults import <domain> <file>`,
forced through `plutil -convert xml1` so git diffs are legible.
Rationale for not symlinking
`~/Library/Preferences/<bundle>.plist` lives in
[ADR-0002](../decisions/0002-no-symlink-preferences.md).

## Layer model — four plist tiers

### `user`

**Path example:** `~/Library/Preferences/com.apple.Terminal.plist`.

- Owned by the logged-in user; `defaults read/write` works without
  additional entitlements.
- **Syncable:** yes. Default tier for most apps Mackup covered.
- Sojourn exports these to `prefs/<bundle_id>.plist` (XML) in the sync
  repo.

### `system`

**Path example:** `/Library/Preferences/com.apple.loginwindow.plist`.

- Owned by root. Sojourn refuses to modify; exposes for display only.
- **Syncable:** no. Changing system-wide prefs needs admin elevation
  Sojourn does not request.

### `sandboxed`

**Path example:**
`~/Library/Containers/com.apple.weather/Data/Library/Preferences/com.apple.weather.plist`.

- Container-scoped. Sojourn is **not** sandboxed and thus *can* read
  these — but doing so requires the user to grant Full Disk Access.
- **Syncable:** v0.2 ships behind an FDA prompt (per
  [v0.2-plan §PrefService extension](../process/plans/v0.2-plan.md)).
  Earlier scoping deferred this to v2; v0.2 promotes it.

### `apple-internal`

**Path example:** `com.apple.LaunchServices.secure.codebless`.

- Apple-managed bookkeeping. Opaque to Mackup-style sync.
- **Syncable:** no. Excluded at the registry level.

## Sync strategy — four-layer pipeline

### Layer 1 — transport: `defaults export` / `defaults import`

Round-trips through `cfprefsd`, updates its in-memory cache, survives
sandbox boundaries. The only first-class Apple-supported path. Sojourn
runs
`defaults export com.foo.bar ~/Library/Application Support/Sojourn/preferences/com.foo.bar.plist`
per tracked domain on push, and the reverse on pull. Preferences are
committed as XML-format plist (`plutil -convert xml1` before commit) so
git diffs are legible.

### Layer 2 — domain classification

Every tracked preference is tagged with a class:

- **plain dotfile** (e.g. `~/.zshrc`) — chezmoi-managed, git-diffable,
  no cfprefsd involvement.
- **unsandboxed plist** (e.g.
  `~/Library/Preferences/com.googlecode.iterm2.plist`) —
  `defaults export/import`.
- **sandboxed plist** (e.g. Safari's container) — needs Full Disk
  Access; Sojourn refuses to sync without FDA granted, using
  `/Library/Preferences/com.apple.TimeMachine.plist` as the canary
  probe (per Apple DevForums thread 114452).
- **Application Support blob** (e.g. keymap files) — rsync copy with
  no cfprefsd round-trip.

The Mackup `applications/` registry (GPL-3, 500+ `.cfg` files) is
**seed material, not verbatim truth**. A meaningful fraction of its
entries point at paths that trip cfprefsd or Containers TCC. Sojourn
forks the registry, re-classifies each entry, and maintains it as its
own data file under `data/applications/*.toml`. License the fork as
GPL-3 (matches Mackup) and credit upstream. Do not vendor the live
Mackup repo.

### Layer 3 — safe-copy discipline

For domains where the target app is running, Sojourn quits-or-prompts
the app before import (AppleScript
`tell application "id:com.foo" to quit`), runs `killall cfprefsd` with
explicit user consent if needed, performs `defaults import`, then
relaunches. Power users can toggle off the quit-and-relaunch and
accept partial sync.

### Layer 4 — don't require FDA by default

Unsandboxed plists and standard user dotfiles cover ~80% of what users
want to sync. Full Disk Access is prompted only when the user
explicitly asks to sync a sandboxed app's preferences. This keeps
onboarding clean; power users pay the TCC cost only when they need it.

## Registry layout

Every supported app has a TOML entry at
`Sojourn/Resources/data/applications/<bundle_id>.toml`. Schema:

```toml
[application]
bundle_id    = "com.apple.Terminal"
domain       = "com.apple.Terminal"
layer        = "user"
syncable     = true
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

v0.2 ships an alternative offline corpus from 8ta4's
[preferences.sh](https://github.com/8ta4/chezmoi/blob/60ab9d48c328362f72d6cd79bac0b1fa35a23eaa/preferences.sh)
as `Sojourn/Resources/preference-domains.json` — read at app launch,
no network required.

## cfprefsd relaunch

On import, Sojourn runs `killall -u $USER cfprefsd` after
`defaults import` so running apps pick up the new values. This kills
only the user's `cfprefsd`; it respawns immediately. Apps with their
own in-memory cache may still need a manual relaunch — the UI surfaces
this as a per-app hint.

## What Sojourn does not attempt

- Binary plist structural diff/merge (beyond `plutil -convert xml1`
  round-trip for storage).
- Key-level selective sync within a plist (deferred to v2).
- Apps that use keychain-backed preferences (e.g. 1Password's
  license).
- Anything in `~/Library/Group Containers` without FDA.

## Discover pane (forward reference)

The v0.1 design PDF (page 36) introduces a "Discover" pane backed by a
`cfprefsd` watcher that records preference changes as the user makes
them. Scope is a maintainer open question — see
[process/open-questions.md](../process/open-questions.md). Decision
landed: deferred to v1.1 record-session model. Full spec lands in
`docs/explain/discover-pane.md` once design ratified.

## See also

- [ADR-0002 — no symlink preferences](../decisions/0002-no-symlink-preferences.md)
- [process/plans/v0.2-plan.md — PrefService extension scope](../process/plans/v0.2-plan.md)
- [explain/why-no-symlink-prefs.md](../explain/why-no-symlink-prefs.md)
- [how-to/preferences/track-app.md](../how-to/preferences/track-app.md)
- [how-to/preferences/handle-sandboxed-app.md](../how-to/preferences/handle-sandboxed-app.md)
- [how-to/preferences/recover-failed-import.md](../how-to/preferences/recover-failed-import.md)
