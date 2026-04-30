# `.sojourn/active.toml` schema

The cooperative writer-lock file. Records the Mac currently authorised
to push to the data repo. Backs the writer-lock model in
[decisions/0012-cooperative-writer-lock.md](../../decisions/0012-cooperative-writer-lock.md);
the rationale is in
[explain/cooperative-locking.md](../../explain/cooperative-locking.md).

## Path

`<data-repo-root>/.sojourn/active.toml`. Tracked by git. Committed on
every push and on every explicit lock-transfer action.

## Shape

```toml
schema_version  = "1"
machine_id      = "MAC-3F7A"
hostname        = "binghzals-MBP"
acquired_at     = "2026-04-30T14:02:11Z"
sojourn_version = "0.1.3"
```

That's it. No fields are optional in v1.

## Lock semantics

The lock is **cooperative, not authoritative**. Git enforces nothing;
the file is purely an advisory record. The check happens in
`SyncCoordinator` at push time:

1. Pull latest.
2. Read `.sojourn/active.toml`.
3. If `machine_id` matches local Mac → proceed with push.
4. If `machine_id` ≠ local → show "Active writer" chip, refuse push,
   require user to click "Take writer lock" to proceed.
5. On take, rewrite `active.toml` with local `machine_id` +
   `acquired_at = now()`, commit, then proceed.

The user-facing chip is the social-protocol layer; the TOML is the
git-tracked record.

## Race window

Two Macs can take the lock simultaneously if their pushes interleave
between pull and write. The race is caught by git's
`non-fast-forward` rejection on the second push, which falls into the
conflict-resolution flow per
[reference/conflict-shapes.md](../conflict-shapes.md). The lock loses
some of its value in this case but doesn't cause data loss.

## Format constraints

- Always exactly one `[active.toml]` per data repo.
- `machine_id` must match a `machines.toml` entry.
- `acquired_at` is ISO 8601 UTC, no fractional seconds, no offset
  notation other than `Z`.
- File is rewritten in-place; no append.

## See also

- [decisions/0012-cooperative-writer-lock.md](../../decisions/0012-cooperative-writer-lock.md)
  — the formal decision record.
- [explain/cooperative-locking.md](../../explain/cooperative-locking.md)
  — full rationale + UX.
- [machines-toml.md](machines-toml.md) — `machine_id` source.
- [how-to/sync/transfer-writer-lock.md](../../how-to/sync/transfer-writer-lock.md)
  — user task for taking over the lock.
