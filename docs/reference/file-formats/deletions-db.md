# `deletions.db` schema

SQLite database recording every Sojourn-initiated deletion or trash
operation. 30-day retention. Used to power the "What did Sojourn
delete?" diagnostics view and to satisfy the audit invariant that
Sojourn never silently drops data.

## Path

`~/Library/Application Support/Sojourn/deletions.db` (per-Mac local;
**not** in the data repo).

## Schema (v1)

```sql
CREATE TABLE deletions (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    deleted_at      TEXT    NOT NULL,    -- ISO 8601 UTC
    operation       TEXT    NOT NULL,    -- 'trash' | 'snapshot-prune' | 'orphan-trash'
    source_path     TEXT    NOT NULL,    -- absolute path before move
    trash_path      TEXT,                -- where it ended up (Trash) or NULL for prune
    bytes           INTEGER NOT NULL,    -- size at delete time
    job_id          TEXT,                -- FK to history.db jobs(id) when applicable
    reason          TEXT,                -- free-form: 'cleanup-pane', 'cooldown-prune', etc.
    confirmed_by_user INTEGER NOT NULL  -- 0 = automated, 1 = user clicked
);

CREATE INDEX idx_deletions_deleted_at ON deletions(deleted_at);
CREATE INDEX idx_deletions_operation ON deletions(operation);
```

## Invariants

- Sojourn **never** uses `rm`. Every delete goes through
  `NSFileManager.trashItem(at:)`.
- Every `trashItem` call writes a row here before returning. If the
  insert fails, the operation aborts.
- 30-day retention: a daily background activity prunes rows where
  `deleted_at < now - 30d`. Pruning is also recorded — as
  `operation = 'snapshot-prune'`.
- `confirmed_by_user = 0` rows can only be created by:
  - cleanup-pane "Move to Trash" actions for items the user reviewed
    in bulk (still confirmed at the bulk level)
  - cooldown-driven snapshot pruning
  - on-disk space pressure (if implemented)
  Any other auto-deletion is a bug.

## Querying for diagnostics

The Cleanup pane's "Recently moved to Trash" tab issues:

```sql
SELECT id, deleted_at, source_path, trash_path, bytes, reason, job_id
FROM deletions
WHERE deleted_at >= ?
ORDER BY deleted_at DESC
LIMIT 200;
```

The diagnostics export bundle (see
[how-to/diagnostics/export-bundle.md](../../how-to/diagnostics/export-bundle.md))
includes the full DB.

## See also

- [reference/cleanup.md](../cleanup.md) — orphan detection +
  trashing flow.
- [history-db.md](history-db.md) — sibling DB for push/pull history.
- [explain/threat-model.md](../../explain/threat-model.md) — invariant
  about never silently dropping data.
- [AGENTS.md](../../../AGENTS.md) — "Do not auto-delete orphans" rule.
