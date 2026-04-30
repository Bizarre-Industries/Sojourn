# Resolve a sync conflict

## Goal

Step through the conflict-resolution flow when Sojourn's pull surfaces
a divergence between the data repo and your local state.

## Prereqs

- A pull has just shown a conflict modal (one of the six conflict
  shapes from [reference/conflict-shapes.md](../../reference/conflict-shapes.md)).

## Steps

1. **Identify the shape**.

   Sojourn labels each finding with one of:

   - **Text edit conflict** — same file edited on both sides.
   - **`packages.toml` diverged** — both sides added / removed
     packages.
   - **chezmoi template conflict** — template body diverged.
   - **Plist conflict** — preference file binary-diverged.
   - **Rename vs edit** — one side renamed, the other edited.
   - **Delete vs edit** — one side deleted, the other edited.

2. **Open the diff pane**.

   Side-by-side or unified per *Settings → Sync → Preview default
   layout*.

3. **Choose a resolution per file**:

   - **Keep mine** — discard incoming change for this file. Other
     files in the same pull still apply.
   - **Take theirs** — discard local edit. Sojourn snapshots local
     first to `~/Library/Application Support/Sojourn/backups/<ts>-resolve/`.
   - **Merge by hand** — open the file in your `$EDITOR` (default
     determined by chezmoi's `merge.command`). Resolve conflict
     markers, save, return.

4. **Confirm** — Sojourn re-runs the apply with your resolutions.

5. **Push** — once the local state matches the merged repo, push
   normally.

## Verification

- Sojourn's status chip shows *Up to date*.
- `git status` in the data repo is clean.
- `chezmoi diff` shows no further drift.
- The History pane lists the conflict-resolve job with the chosen
  resolutions.

## Troubleshooting

- **"Merge editor doesn't open"** — chezmoi reads `merge.command`
  from `~/.config/chezmoi/chezmoi.toml`. Sojourn's bootstrap should
  set this; if not, see audit §6.5.
- **"Pull keeps refusing"** — the cooperative writer lock is held
  by another Mac. See
  [transfer-writer-lock.md](transfer-writer-lock.md) before pulling.
- **"Wrong file resolved"** — the snapshot in `backups/` has the
  pre-resolution state. Restore via Cleanup pane → *Restore from
  backup*.

## See also

- [reference/conflict-shapes.md](../../reference/conflict-shapes.md)
  — the six shapes + UI mappings.
- [reference/sync-model.md](../../reference/sync-model.md) — full
  push/pull state machine.
- [explain/cooperative-locking.md](../../explain/cooperative-locking.md).
