# 0002 — Do not symlink preferences; use `defaults export/import`

- **Status**: Accepted
- **Date**: 2026-04-24
- **Deciders**: Sojourn maintainer

## Context

Mackup, the historical incumbent for Mac preference sync, symlinks
`~/Library/Preferences/com.foo.bar.plist` to a sync folder. This has been
**effectively broken since macOS 12 (Monterey)**. `cfprefsd` flushes plist
state via atomic rename (write to tmp, rename over destination) — the
rename replaces the symlink with a regular file, silently breaking sync.
Sonoma+ tightens this further with hardened container TCC and more
aggressive flushing.

Mackup's own README ships a WARNING banner; PR #2085 added copy-mode as a
fallback but it is not a live sync.

## Decision

Sojourn round-trips preferences through `defaults export <domain> <file>`
on push and `defaults import <domain> <file>` on pull. Round-trip goes
through `cfprefsd`'s public API, updates its in-memory cache, and survives
sandbox boundaries. Storage format is XML plist (`plutil -convert xml1`)
so git diffs are legible.

## Consequences

### Positive

- Correctness — never silently desync.
- Survives Apple's tightening of `cfprefsd` and Container TCC.
- Diffs are legible XML, not opaque binary plist.
- No FDA required for unsandboxed apps (the 80% case).

### Negative

- Snapshot-based, not live. The user pays the snapshot cost on every
  push/pull rather than getting continuous sync.
- Apps with their own in-memory cache may need manual relaunch after
  `defaults import` (Sojourn surfaces this as a per-app hint).

### Neutral

- The four-layer strategy (plain dotfile / unsandboxed plist / sandboxed
  plist / Application Support blob) is documented in
  [reference/preferences.md](../reference/preferences.md).
- The Mackup `applications/` registry is reused as **seed material**, not
  verbatim truth — see [reference/preferences.md](../reference/preferences.md).

## Alternatives considered

- **Continue Mackup's symlink model** — rejected. Demonstrably broken on
  Sonoma+; user data loss when symlinks get clobbered.
- **iCloud Keychain / iCloud Drive sync** — out of Sojourn's lane;
  Apple-owned UX, no programmatic surface.
- **Live `cfprefsd` watcher with debounced commits** — considered for
  the Discover pane (deferred per audit §8 Q4); orthogonal to the
  push/pull model and not a replacement for it.
