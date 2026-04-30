# Cooperative locking, not three-way merge

Sojourn's multi-Mac sync model is **explicit push/pull with a
cooperative writer lock**. Two Macs cannot push simultaneously; the
second one's push fails on git's `non-fast-forward` rejection and the
user goes through a guided conflict-resolution flow. Three-way merge
with per-file timestamps is deferred to a later release. The decision
is in
[decisions/0012-cooperative-writer-lock.md](../decisions/0012-cooperative-writer-lock.md);
this page is the explanation.

## The locking options

Three real choices:

1. **Authoritative lock** — Sojourn-operated server arbitrates writes.
   Conflicts with the local-only stance ([decisions/0001-ipc-not-linking.md](../decisions/0001-ipc-not-linking.md)
   has a sister principle: no Sojourn server). Rejected.
2. **Three-way merge with per-file timestamps.** The right answer for
   v2. Requires per-file-shape conflict UI (text, plist, packages.toml,
   chezmoi templates). Significant scope and UX research. Deferred.
3. **Cooperative lock + git's native conflict semantics.** Cheap to
   ship. Catches the 95% case (user forgot to pull). Misses the 5%
   case (true simultaneous race), where git's own
   `non-fast-forward` rejection takes over. Chosen for v1.

## How the cooperative lock works

The data repo has a `.sojourn/active.toml` file:

```toml
machine_id = "MAC-3F7A"
hostname   = "binghzals-MBP"
acquired_at = "2026-04-30T14:02:11Z"
sojourn_version = "0.1.3"
```

The flow:

- Before push, Sojourn writes itself into `active.toml` and commits.
- The footer chip in the UI shows `Active writer · binghzals-MBP, 2h
  ago`.
- A different Mac that opens the same data repo sees the chip and
  knows not to push.
- If the same-Mac user wants to take the writer lock, they click the
  chip and the chip's machine field is rewritten.
- Push proceeds normally.

The lock is **advisory**: git enforces nothing. Two Macs with
out-of-date views can still race. When that happens:

- Mac A pushes, succeeds.
- Mac B pushes, gets `non-fast-forward` rejection.
- Mac B's UI shows the conflict-resolution flow per
  [reference/conflict-shapes.md](../reference/conflict-shapes.md).

The lock catches the common case (user forgot to pull). The fallback
catches the rare case (true race).

## Why not three-way merge in v1

Three-way merge is the right long-term model. It just costs more than
v1 can absorb:

- **Per-file-shape merge logic.** Text dotfiles merge with `git
  merge-file` semantics. Plists need plist-aware merge (chezmoi's own
  maintainers say plist line-merge is incorrect; the file is a tree).
  `packages.toml` needs key-merge with conflict-on-divergence.
  Each shape is its own UI surface.
- **Per-file timestamps in the data model.** Currently a commit is the
  unit of "what state was this Mac in"; per-file timestamps require
  rethinking that.
- **Conflict-resolution UI for 6 distinct shapes** (text edit, packages
  diverged, chezmoi template, plist, rename vs edit, delete vs edit).
  Each needs spec, design, test fixtures.

v1 ships the cooperative lock + the conflict-shape catalogue in
[reference/conflict-shapes.md](../reference/conflict-shapes.md) as the
target for the eventual v2 work.

## Why not server-side authoritative

Sojourn is local-only by design ([explain/design-philosophy.md](design-philosophy.md)
"No telemetry, no server"). Adding a Sojourn-operated server for
write arbitration alone:

- Forces every user to register with us before multi-Mac sync works.
- Creates a single point of failure for Sojourn's core flow.
- Conflicts with the "user owns their data" stance — the user's git
  remote is supposed to be the only durable surface.
- Multiplies the support and trust burden enormously.

Cooperative-lock + git-rejection is the worst-of-both-worlds-but-it-works
pragmatic solution.

## What this costs the user

**Concurrent multi-Mac edits don't merge automatically.** If you edit
the same dotfile on Mac A and Mac B without syncing, you get a
conflict-resolution flow when Mac B tries to push. The flow is guided
(diff pane, side-by-side view, "keep mine / theirs / merge by hand")
but it's still a manual step.

Most users will only hit this if they actively forget to pull.
Single-Mac users never hit it.

## Footer chip UX

The "Active writer" footer chip is the social-protocol layer of the
lock. It teaches the user to look before pushing. The chip shows:

- Active writer machine name.
- Acquired-at timestamp ("2 hours ago").
- A click-to-take-over action (with a confirmation dialog: "Mac B is
  the active writer; pull from there before pushing here").

Audit §4.2.15 flags that the chip becomes stale on disconnect — it
needs a network-aware refresh that re-checks the remote on focus. The
v1 chip is best-effort.

## See also

- [decisions/0012-cooperative-writer-lock.md](../decisions/0012-cooperative-writer-lock.md)
  — the formal decision record.
- [reference/sync-model.md](../reference/sync-model.md) — full
  push/pull flow + lock interactions.
- [reference/conflict-shapes.md](../reference/conflict-shapes.md) —
  the six shapes the conflict-resolution UI handles.
- [how-to/sync/transfer-writer-lock.md](../how-to/sync/transfer-writer-lock.md)
  — how the user takes over the lock.
- [how-to/sync/resolve-conflict.md](../how-to/sync/resolve-conflict.md)
  — what to do when the lock fallback fires.
