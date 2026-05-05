# Carry vs sync — vocabulary

> **Audit driver**: vocabulary support for [process/audit-2026-04.md §2.2.1](../process/audit-2026-04.md#22-chezmoi-features-not-surfaced) ("carry whole shell setup" workflow as B-priority) + general audit usage of both terms.

The Sojourn UI uses both "carry" and "sync" to describe what's
happening to the user's setup. They are not synonyms. This page pins
the terms down so contributors can use them consistently in copy,
docs, and tickets.

## The two operations

### Carry

**Carry** is the one-shot transport operation: bring my setup to a Mac
that doesn't have it yet. Examples:

- Buy a new MacBook → install Sojourn → onboard from existing repo →
  packages, dotfiles, and prefs are now on the new machine.
- Wipe and reinstall macOS → recover from the data repo.
- Borrow a teammate's Mac for a week → carry your shell setup so your
  muscle memory still works.

Carry is **directional and finite**. The destination Mac receives the
state; the source repo is unchanged. After carry completes, the Mac
either becomes a sync participant (most common) or stays as a
read-only mirror (rare; not a v1 mode).

The audit calls this out explicitly when discussing
[`.chezmoiexternal.toml`](../reference/externals.md): externals are a
**B-priority "carry whole shell setup" feature** because the value of
carry depends on transporting third-party shell frameworks
(oh-my-zsh, prezto, lazy.nvim) that the user did not author and so
chezmoi cannot version directly.

### Sync

**Sync** is the ongoing reconciliation operation: keep two or more
Macs in agreement over time. Examples:

- Install a new package on Mac A → push → pull on Mac B →
  Mac B has the package.
- Edit `.zshrc` on Mac A → push → pull on Mac B → both now have the
  edit.
- Change a Sublime Text preference on Mac A → push → pull on Mac B →
  both Macs reload the new pref.

Sync is **bidirectional and continuous**. Either Mac can originate a
change; the cooperative writer lock
([explain/cooperative-locking.md](cooperative-locking.md)) ensures
they alternate cleanly.

Sojourn is fundamentally a sync product; carry is the special case of
sync starting from an empty destination.

## How to tell which one you're doing

The UI distinguishes them implicitly:

| Surface | Operation | Notes |
|---|---|---|
| Onboarding flow → "Set up new repository" | Bootstrap (neither) | Repo is created empty |
| Onboarding flow → "Onboard from existing repository" | **Carry** | Destination is new |
| `Push` button after edits | **Sync** (write) | Source pushes new state |
| `Pull` button | **Sync** (read) | Destination pulls peer state |
| `Pull and apply` after long offline | Sync that *feels like* carry | Many changes at once |
| `Restore from backup` | Carry from snapshot | Source is local backup, not remote |

The cooperative writer lock applies only to sync. Carry from a fresh
clone doesn't take the lock — the destination Mac wasn't a writer
before.

## Why this matters

Reviewers, docs writers, and bug filers conflate the two. Symptoms:

- "Sojourn doesn't sync my new install fast enough" → almost always a
  carry-flow report (first-time onboarding) where the user expected
  the sync cadence.
- "Sync deleted my local edits" → almost always a sync-with-pending-pull
  story where the user pushed from the wrong Mac. The deletion was
  carry-like behaviour applied where sync semantics were expected.
- "Carry from one Mac to another lost my prefs" → almost always a
  classification problem where the prefs are sandboxed and Sojourn
  declined to carry without FDA opt-in.

Naming the operation correctly upfront usually clarifies the bug.

## Implementation: same primitives, different orchestration

Carry and sync share the underlying primitives:

- `chezmoi apply` writes dotfiles.
- `brew bundle install` writes packages.
- `defaults import` writes prefs.
- The pre-snapshot, conflict-resolution, and cooldown machinery applies
  to both.

The difference is in `SyncCoordinator` orchestration:

- **Carry**: skip conflict-resolution (the destination has nothing to
  conflict with). Skip the writer-lock check (no writer exists).
  Always apply, never merge.
- **Sync**: full pull-preview / conflict-resolution / writer-lock
  flow. `chezmoi diff` first, `chezmoi merge` for text dotfiles,
  `brew bundle install` only after explicit confirmation, etc.

The same code paths run; the user-facing flow differs.

## Out-of-scope claims

- Sojourn does **not** offer "live sync" (per-keystroke replication).
  Sync is explicit push/pull only ([reference/sync-model.md](../reference/sync-model.md)).
- Sojourn does **not** offer "carry without sync" as a permanent mode.
  A Mac that has carried can either stay a sync participant or detach
  fully (re-bootstrap with a new repo); there is no read-only
  long-term mode in v1.
- Sojourn does **not** distinguish carry-from-snapshot from carry-from-remote
  in the UI today; both surface as "Restore" or "Onboard from existing
  repository".

## See also

- [reference/sync-model.md](../reference/sync-model.md) — the
  push/pull state machine.
- [explain/cooperative-locking.md](cooperative-locking.md) — what
  governs concurrent writers in the sync case.
- [explain/bootstrap-state-machine.md](bootstrap-state-machine.md) —
  the carry entry path on a fresh Mac.
- [reference/externals.md](../reference/externals.md) — why externals
  are explicitly a carry-priority feature.
