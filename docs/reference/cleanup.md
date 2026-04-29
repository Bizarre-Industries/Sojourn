# Cleanup / orphan detection

No existing tool does this for dotfiles specifically. `~/Library/**` orphan
detection is solved by Pearcleaner (active SwiftUI, open source, 5.4.3),
AppCleaner (12+ years old, still works), PureMac, MyMacCleaner. All of them
work by bundle-ID reconciliation against `~/Library`. None look at `~/.foo`
dotfiles, because dotfile names rarely match bundle IDs.

## Primary signal: dotfile vs tool-presence inventory

Reconcile `~/.foo`-style configs against a tool-presence inventory. Ship a
curated mapping `data/dotfile_owners.toml`:

```toml
".zshrc" = { tool = "zsh", source = "system|brew" }
".gitconfig" = { tool = "git", source = "system|brew" }
".aws" = { tool = "awscli", source = "brew|pip" }
".rbenv" = { tool = "rbenv", source = "brew" }
# ...
```

For each entry, mark orphan if none of the tool's sources are installed
(checked against `brew list`, `pipx list`, `$PATH` probe, mpm-managed
registry).

## Secondary gating signals

Reduce false positives — none are auto-delete:

- Shell history grep (`grep -l basename ~/.zsh_history ~/.bash_history`)
  within 180 days → keep.
- `com.apple.lastuseddate#PS` xattr within 180 days → keep.
- Parent dir mtime within 30 days → keep.

## APFS atime

**Not usable as authoritative "last used."** Default mount is non-strict
atime; Quick Look updates it, some API paths do not, Spotlight/Time Machine
can tick it. Use only as a tiebreaker. Document this so sophisticated users
don't ask why atime is ignored.

## `~/Library/**` orphans

Bundle-ID reconciliation (the Pearcleaner model): enumerate `/Applications`,
`~/Applications`, cask artifacts, MAS receipts
(`/Library/Application Support/App Store/receipts/`); extract
`CFBundleIdentifier`; match against `~/Library/{Preferences,
Application Support, Containers, Group Containers, Caches, LaunchAgents,
Saved Application State}`; candidates with no owning app are orphans.

## Classification per orphan

- **safe**: caches, saved app state.
- **review**: preferences, Application Support.
- **risky**: containers (may hold user documents), LaunchAgents,
  keychain-adjacent files.

## Actions

- Always move to Trash (`NSFileManager.trashItem`), never `rm`. Trash is
  the undo log for 10 most recent actions.
- Also keep an SQLite `deletions.db` under Application Support with path,
  checksum, timestamp, and reason — so a user can reconstruct or audit.
- No auto-delete. Always user confirmation. The Mac cleanup UX pattern is
  well-understood here (AppCleaner, Pearcleaner).
