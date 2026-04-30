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

Per [process/open-questions.md](../../process/open-questions.md) §5
(closed 2026-04-30): `history.db` is forensic data, not recoverability
data, so retention horizon is the attack window — not the
`deletions.db` 30-day window which matches Trash recoverability.

| Table | Retention | Rationale |
|---|---|---|
| `jobs` | **365 days** (default) | xz precedent: ~24-month maintainer-infiltration ramp. Need 12–24 month lookback to trace "when did this version land?" Cost is trivial — ~700KB/year at 5 ops/day. |
| `job_logs` | **90 days** (default) | Heavier rows. 10000 lines/job × 100 bytes × 5 jobs/day × 90 days ≈ 450MB worst-case; capped further by `history.max_log_lines_per_job`. |

Backstop: `history.max_db_size_mb` (default 500MB). Oldest-first eviction
across both tables when exceeded.

User-configurable via [reference/settings.md](../settings.md):
`history.retention_days_jobs`, `history.retention_days_logs`,
`history.max_db_size_mb`.

A daily background activity (`app.bizarre.sojourn.history-prune`) runs
both retention sweeps and writes a `'prune'` row per sweep so the user
can see eviction in the History pane.

Side effect of the 365d default: `diagnostics.bundle_includes_history_db`
(default `true`) carries useful debugging history when users export a
diagnostic bundle for support. The previous 30d window made bundles
near-useless for week-old bug reports.

## Invariants

- Every `Job` created by `JobRunner` writes a `jobs` row before
  starting and updates `finished_at` + `exit_code` on completion.
- `job_logs` rows stream in as `LogBuffer` flushes (per N lines or
  per timer).
- `backup_path` is set by `SnapshotService` for any destructive
  operation.
- A `Job` whose subprocess hangs / is killed gets `exit_code = NULL`
  and `error_message = "killed: timeout"` or similar.
- Retention sweeps never delete `jobs` rows that have a non-NULL
  `backup_path` pointing at a snapshot directory that still exists —
  prevents orphaning backup metadata.

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

Forensic query — "when did `xz-utils` first land on this Mac?":

```sql
SELECT j.started_at, j.operation, jl.body
FROM jobs j
JOIN job_logs jl ON jl.job_id = j.id
WHERE jl.body LIKE '%xz-utils%'
  AND j.operation IN ('pull', 'restore', 'apply')
ORDER BY j.started_at ASC
LIMIT 1;
```

This query depends on `job_logs` retention being long enough; with the
default 90d, the lookback window for log-text grep is 90d. The `jobs`
table itself retains for 365d so `started_at` history is queryable
even after log lines have been pruned.

## See also

- [deletions-db.md](deletions-db.md) — sibling DB.
- [reference/sync-model.md](../sync-model.md) — push/pull operations
  that produce job rows.
- [process/audit-2026-04.md §3.3](../../process/audit-2026-04.md#33-models)
  — original gap analysis.
- [process/open-questions.md](../../process/open-questions.md) §5 —
  retention policy decision (closed).
