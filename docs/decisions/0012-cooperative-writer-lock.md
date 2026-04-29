# 0012 — Cooperative writer lock; defer three-way merge to v2

- **Status**: Accepted
- **Date**: 2026-04-24
- **Deciders**: Sojourn maintainer

## Context

Multi-Mac sync produces concurrent-write conflicts when two Macs push
without a coordination protocol. Three options:

1. **Authoritative locking** — would need a Sojourn-operated server.
   Conflicts with the local-only stance.
2. **Three-way merge with per-file timestamps** — the v2 target. Requires
   conflict-resolution UI for every file shape (text, plist, packages.toml,
   chezmoi templates). Significant scope.
3. **Cooperative writer lock + git's native conflict semantics** —
   cheap to ship in v1.

## Decision

For v1, Sojourn writes a `.sojourn/active.toml` file in the data repo
recording the current writer (machine_id + hostname + timestamp). Only
the active writer can push; other Macs must pull first and explicitly
take the writer lock before they can push.

The lock is **cooperative, not authoritative** — git has no native
locking. If two Macs race, the second one's push fails on the standard
`non-fast-forward` rejection and they go through the conflict-resolution
flow ([reference/conflict-shapes.md](../reference/conflict-shapes.md)).

The cooperative lock catches the 95% case of a user forgetting to pull
first, which is what we actually need.

## Consequences

### Positive

- Ships in v1 without a server.
- The lock visibility (footer chip "Active writer · 2h ago") trains user
  habits to pull before push.
- v2 three-way merge can be added incrementally without breaking the
  lock model.

### Negative

- Race conditions still possible — the lock is advisory.
- Footer chip becomes stale on disconnect; needs network-aware refresh
  (audit §4.2.15).

### Neutral

- The six conflict shapes (text edit, packages.toml diverged, chezmoi
  template, plist, rename vs edit, delete vs edit) have UI handlers in
  `ConflictResolutionView` per
  [reference/conflict-shapes.md](../reference/conflict-shapes.md).

## Alternatives considered

- **Authoritative server-side lock** — rejected. Requires a Sojourn
  server; out of project scope.
- **Three-way merge in v1** — rejected. Scope creep; v1 ship gates on
  this.
- **No lock; rely on git** — rejected. git's `non-fast-forward` rejection
  works but the user-facing UX of "your push was rejected, pull first"
  is hostile. Surfacing the lock as a chip is friendlier.
