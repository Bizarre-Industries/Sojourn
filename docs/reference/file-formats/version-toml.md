# `.sojourn/version.toml` schema

Schema-version pin for the data repo. Sojourn checks this on every
read; mismatched versions either trigger a migration or refuse the
operation with a "this repo was last touched by a newer Sojourn"
message.

## Path

`<data-repo-root>/.sojourn/version.toml`. Tracked by git.

## Shape

```toml
schema_version = "1"
last_writer_version = "0.1.3"
last_writer_date    = "2026-04-30T14:02:11Z"
```

## Migration semantics

When Sojourn opens a data repo:

- If `schema_version` is **older** than the running Sojourn — Sojourn
  runs the migration ladder for each intervening version, writes a
  pre-migration snapshot to `~/Library/Application Support/Sojourn/backups/<ts>-migrate/`,
  updates `version.toml`, commits.
- If `schema_version` is **newer** — Sojourn refuses to operate; UI
  shows "This repo was last written by Sojourn vN.M; please upgrade."
  No partial writes.
- If `schema_version` is **equal** — proceed normally; on push,
  update `last_writer_version` + `last_writer_date`.

The schema-version ladder lives in `Sojourn/Sync/Migrations/`. Each
migration is a one-way transformation. There is no downgrade path —
users on older Sojourn must upgrade to read newer-schema repos.

## Format constraints

- TOML 1.0.
- `schema_version` is a string of the form `"<int>"`. v1 uses `"1"`.
- `last_writer_version` is the SemVer string from the last `git push`.
- `last_writer_date` is ISO 8601 UTC.

## See also

- [packages-toml.md](packages-toml.md) — has its own
  `schema_version` field; the two move in lockstep.
- [process/release.md](../../process/release.md) — release-prep
  checklist that bumps `schema_version` when a migration ships.
