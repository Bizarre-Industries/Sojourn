# Sync model

> **Audit driver**: drives [process/audit-2026-04.md §2.2.3](../process/audit-2026-04.md#22-chezmoi-features-not-surfaced) (`chezmoi merge` for text dotfiles, Phase 12) + §2.5 (SSH known_hosts boilerplate, Phase 4 slot-in).

**Explicit push/pull, one active writer at a time.** Not continuous
bidirectional sync. Conflict handling on concurrent writes is deferred to v2
and loudly flagged in UI. See
[decisions/0012-cooperative-writer-lock.md](../decisions/0012-cooperative-writer-lock.md).

## Model

- Each Mac has a `machine_id` (UUID generated on first run, stored in
  `~/Library/Application Support/Sojourn/machine.json`).
- The git repo stores per-machine metadata under `.sojourn/machines/<id>.toml`:
  hostname, human name, last push timestamp, last push commit SHA, chezmoi
  age recipient.
- One machine is marked `active_writer` in `.sojourn/active.toml`. Only the
  active writer may push; others must pull first and explicitly take the
  writer lock.

## Operations

- **Push** (user clicks Push): Sojourn captures current state (`mpm backup`
  → `packages.toml`; `chezmoi re-add` for any user-modified managed files;
  `defaults export` for each tracked preference domain); runs gitleaks; shows
  a diff; user confirms; commits; pushes; updates `.sojourn/active.toml`.
- **Pull** (user clicks Pull): `git fetch`; show inbound diff; user confirms;
  `git pull`; `mpm restore packages.toml` (with cooldown and tier gating —
  see [reference/cooldown-policy.md](cooldown-policy.md));
  `chezmoi apply` with `--force` after user-confirmed diff; `defaults import`
  for each tracked domain (round-tripped through cfprefsd —
  see [reference/preferences.md](preferences.md)).
- **Take writer lock**: explicit action. Writes a new `active.toml` in a
  commit. Prevents another Mac from pushing without also pulling and taking
  the lock. This is cooperative, not authoritative — git has no locking —
  but it catches the 95% case of a user forgetting to pull first.

## Per-machine overrides via chezmoi templates

chezmoi templates get us most of the way. The app exposes a "Per-machine
overrides" pane that edits `.chezmoidata.toml` and, per file, offers to wrap
a section in `{{ if eq .chezmoi.hostname "work-mbp" }}…{{ end }}`. The
template language is Go text/template; the UI hides this behind a form
("Apply this block only on: [machine picker]") and generates the boilerplate.

Package overrides: `packages.toml` sections are already per-manager. Sojourn
extends the schema with optional per-machine gating:

```toml
[brew]
ripgrep = "*"
fd = "*"

[brew.only."work-mbp"]
slack = "*"

[brew.exclude."personal-mini"]
docker = "*"
```

The app reconciles this to `mpm restore` calls on a per-machine computed
subset. This is a Sojourn-side feature; the underlying `mpm backup` /
`restore` format is unchanged (the gating keys live in separate tables, not
in mpm's own).

## Conflict handling (v1)

- On pull, if there are uncommitted local changes, refuse and show the user
  the diff. User can stash (Sojourn commits a WIP branch) or discard.
- On push, if remote has diverged, refuse and require pull. No auto-merge.
- Garbage collection: Sojourn keeps a local `.sojourn/backups/` of
  pre-operation snapshots for rollback, 30-day retention.
- The six conflict shapes (text edit, packages.toml diverged, chezmoi
  template, plist, rename vs edit, delete vs edit) are enumerated in
  [reference/conflict-shapes.md](conflict-shapes.md).

v2 will add: last-writer-wins with per-file metadata timestamps, three-way
merge via `git merge-file` for text, side-by-side conflict resolution for
plist diffs.

## Authentication

BYO remote is the default (`git@github.com:user/sojourn-data.git` style;
works for any host). Optional GitHub Device Flow for users who don't have a
remote yet. Sojourn owns and maintains the OAuth App; the app stores only
`client_id`, never `client_secret`. See
[explain/bootstrap-state-machine.md](../explain/bootstrap-state-machine.md).
