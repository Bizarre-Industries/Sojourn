# Revert a push

## Goal

Undo a recent push that caused issues on peer Macs (broken `packages.toml`,
unintentional dotfile rewrite, accidental secret commit caught
post-push).

## Prereqs

- A pushed commit you want to undo.
- Peer Macs have not yet pulled (best case) or have pulled and need to
  revert too (more involved).

## Steps

### Best case: nobody pulled yet

1. Open the History pane → find the recent push.
2. Click *Revert this push*.
3. Sojourn:
   - Runs `git revert <commit>` in the data repo (creates a forward
     revert commit; never rewrites history).
   - Re-runs the appropriate apply (`mpm restore`, `chezmoi apply`,
     `defaults import`) so this Mac is back to the pre-push state.
   - Pushes the revert.

### Peer Macs already pulled

1. Same as above on the originating Mac (creates the revert commit).
2. On every peer Mac:
   - Open the Pull/push bar → *Pull*.
   - Sojourn shows the revert in the preview.
   - *Apply* → peer Mac is also back to pre-push state.

### Catastrophic case: secret leaked

If the revert is because a secret was pushed:

1. Run the standard revert flow (above).
2. **Rotate the credential anyway** — the secret was on the remote in
   plaintext, even briefly. Treat as leaked.
3. If pushed to a public repo: file a takedown request with the host
   (GitHub: Support → Sensitive data removal) and rotate **all
   credentials in that file**, not just the obvious one.
4. Audit `git log --all -- <file>` for any other commits that touched
   the file with the secret; revert those too.

## Verification

- The data repo's `HEAD` is the revert commit.
- The reverted state is applied locally.
- `gitleaks dir` against the data repo finds no leaks.
- Peer Macs show *Up to date*.

## What this does not do

- Sojourn never `force-push` rewrites history. The commit you reverted
  stays in the git log; it just isn't the current state. To fully
  remove a leaked secret from git history, use BFG Repo-Cleaner or
  `git filter-repo` manually — Sojourn refuses to automate that
  (destructive, hard to recover).

## Troubleshooting

- **"Revert produced its own conflicts"** — the changes since the
  reverted commit overlap with the reverted code. Resolve via the
  standard conflict flow ([resolve-conflict.md](resolve-conflict.md)).
- **"Peer Mac applied changes I'm reverting"** — they need to pull
  the revert commit and apply it. Their backup directory has the
  pre-revert state if they need to restore individual files.

## See also

- [reference/sync-model.md](../../reference/sync-model.md).
- [how-to/secrets/handle-finding.md](../secrets/handle-finding.md) —
  for pre-push catches.
