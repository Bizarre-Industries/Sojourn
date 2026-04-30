# Preference sync (plist round-trip)

> **Audit driver**: tracks [process/audit-2026-04.md §1.5](../process/audit-2026-04.md#1-doc-level-inconsistencies) (Discover-pane cfprefsd watcher; open question) + drives audit §4.1.* prefs-pane wiring.

Sojourn's pref-sync strategy in four layers. See
[decisions/0002-no-symlink-preferences.md](../decisions/0002-no-symlink-preferences.md)
for the rationale. For the layer model in detail, see
[reference/pref-domains.md](pref-domains.md).

## Layer 1: transport is `defaults export` / `defaults import`

Round-trips through `cfprefsd`, updates its in-memory cache, survives
sandbox boundaries. This is the only first-class Apple-supported path.
Sojourn runs `defaults export com.foo.bar
~/Library/Application Support/Sojourn/preferences/com.foo.bar.plist` per
tracked domain on push, and the reverse on pull. Preferences are committed
as XML-format plist (runs `plutil -convert xml1` before commit) so git
diffs are legible.

## Layer 2: domain classification

Every tracked preference is tagged with a class:

- **plain dotfile** (e.g., `~/.zshrc`) — chezmoi-managed, git-diffable, no
  cfprefsd involvement.
- **unsandboxed plist** (e.g., `~/Library/Preferences/com.googlecode.iterm2.plist`)
  — `defaults export/import`.
- **sandboxed plist** (e.g., Safari's container) — requires Full Disk Access;
  Sojourn refuses to sync these without FDA granted (and uses
  `/Library/Preferences/com.apple.TimeMachine.plist` read as the canary
  probe, per Apple DevForums thread 114452).
- **Application Support blob** (e.g., keymap files) — rsync copy with no
  cfprefsd round-trip.

The Mackup `applications/` registry (GPL-3, ~500+ .cfg files) is **seed
material, not verbatim truth**. A significant fraction of its entries point
at paths that will trip cfprefsd or Containers TCC. Sojourn forks the
registry, re-classifies each entry, and maintains it as its own data file
under `data/applications/*.toml`. License the fork as GPL-3 (matching
Mackup) and credit upstream. Do not vendor the live Mackup repo.

## Layer 3: safe-copy discipline

For domains where the target app is running, Sojourn quits-or-prompts the
app before import (AppleScript `tell application "id:com.foo" to quit`),
runs `killall cfprefsd` with explicit user consent if needed, performs
`defaults import`, then relaunches. Power users can toggle off the
quit-and-relaunch and accept partial sync.

## Layer 4: don't require FDA by default

Unsandboxed plists and the standard user dotfiles cover 80% of what users
want to sync. Full Disk Access is prompted only when the user explicitly
asks to sync a sandboxed app's preferences. This keeps the onboarding
experience clean; power users pay the TCC cost only when they need it.

## What Sojourn does not attempt

Binary plist structural diff/merge (beyond `plutil -convert xml1` round-trip
for storage), key-level selective sync within a plist (deferred to v2), apps
that use keychain-backed preferences (e.g., 1Password's license), or
anything in `~/Library/Group Containers` without FDA.

## Discover pane (forward reference)

The v0.1 design PDF (page 36) introduces a "Discover" pane backed by a
`cfprefsd` watcher that records preference changes as the user makes them.
Scope is a maintainer open question — see
[process/open-questions.md](../process/open-questions.md). Full spec lands
in `docs/explain/discover-pane.md` once the decision is made.
