# `history.db` schema

SQLite database recording every push, pull, restore, apply, and
secret-scan invocation. Powers the History pane's timeline view and
satisfies the audit's call for a structured history store
([process/audit-2026-04.md §3.3.1](../../process/audit-2026-04.md#33-models)).

Lands in implementation Phase 11 §3.1.6.

## Path

`~/Library/Application Support/Sojourn/history.db` (per-Mac local;
**not** in the data repo).

## Schema (v1)

```sql
CREATE TABLE jobs (
    id              TEXT    PRIMARY KEY,    -- UUID
    started_at      TEXT    NOT NULL,       -- ISO 8601 UTC
    finished_at     TEXT,                   -- NULL while running
    operation       TEXT    NOT NULL,       -- 'push' | 'pull' | 'restore' | 'apply' | 'scan' | 'backup' | 'merge'
    initiator       TEXT    NOT NULL,       -- 'user' | 'background-activity' | 'osv-bypass'
    exit_code       INTEGER,                -- NULL while running, 0 = success
    bytes_processed INTEGER NOT NULL DEFAULT 0,
    backup_path     TEXT,                   -- pre-op snapshot path or NULL
    error_message   TEXT                    -- short error summary on non-zero exit
);

CREATE TABLE job_logs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id          TEXT    NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    seq             INTEGER NOT NULL,         -- monotonic per job
    stream          TEXT    NOT NULL,         -- 'stdout' | 'stderr' | 'system'
    body            TEXT    NOT NULL,         -- one line, ANSI-stripped
    logged_at       TEXT    NOT NULL,
    UNIQUE(job_id, seq)
);

CREATE INDEX idx_jobs_started_at ON jobs(started_at);
CREATE INDEX idx_jobs_operation ON jobs(operation);
CREATE INDEX idx_job_logs_job_id_seq ON job_logs(job_id, seq);
```

## Retention

Open question (see
[process/open-questions.md](../../process/open-questions.md) §5):

- `deletions.db` is 30 days.
- Default for `history.db` is also 30 days for consistency.
- Maintainer may extend to 90 days or unbounded.

## Invariants

- Every `Job` created by `JobRunner` writes a `jobs` row before
  starting and updates `finished_at` + `exit_code` on completion.
- `job_logs` rows stream in as `LogBuffer` flushes (per N lines or
  per timer).
- `backup_path` is set by `SnapshotService` for any destructive
  operation.
- A `Job` whose subprocess hangs / is killed gets `exit_code = NULL`
  and `error_message = "killed: timeout"` or similar.

## Querying

History pane's "Recent activity" tab issues:

```sql
SELECT id, started_at, finished_at, operation, initiator, exit_code, error_message
FROM jobs
ORDER BY started_at DESC
LIMIT 200;
```

Detail view fetches logs for a single job:

```sql
SELECT seq, stream, body, logged_at
FROM job_logs
WHERE job_id = ?
ORDER BY seq;
```

## See also

- [deletions-db.md](deletions-db.md) — sibling DB.
- [reference/sync-model.md](../sync-model.md) — push/pull operations
  that produce job rows.
- [process/audit-2026-04.md §3.3](../../process/audit-2026-04.md#33-models)
  — original gap analysis.
- [process/open-questions.md](../../process/open-questions.md) §5 —
  retention policy (open).
