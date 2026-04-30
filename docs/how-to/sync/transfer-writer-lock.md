# Take over the writer lock

## Goal

Move the cooperative writer lock from another Mac to this one so this
Mac can push.

## Prereqs

- The data repo has an `.sojourn/active.toml` recording another Mac
  as the active writer.
- You have pulled the latest state.

## Steps

1. **Pull first**.

   The footer chip shows the current writer
   (e.g. *Active writer · binghzals-MBP, 2h ago*). Click *Pull*. If
   pull surfaces conflicts, resolve them via
   [resolve-conflict.md](resolve-conflict.md) before continuing.

2. **Click the footer chip**.

   A dialog opens:

   > Mac `binghzals-MBP` is the active writer (acquired 2 hours
   > ago). Take over so this Mac can push?
   >
   > Cancel · Take writer lock

3. **Confirm** *Take writer lock*. Sojourn:

   - Rewrites `.sojourn/active.toml` with this Mac's
     `machine_id` + `acquired_at = now()`.
   - Commits the change with message `chore: take writer lock from
     <prev-machine_id>`.
   - The footer chip updates to show this Mac.

4. **Push** — proceeds normally.

## Verification

- The footer chip shows this Mac as the active writer.
- `.sojourn/active.toml` in the data repo lists this Mac's
  `machine_id`.
- The peer Mac (on next refresh) sees the chip update to your Mac.

## When the previous writer is offline

If the previous writer Mac has been offline for a long time (e.g. a
work laptop on vacation):

1. Verify it really is offline — pull on this Mac, check the chip's
   timestamp.
2. Use *Take writer lock* anyway. The peer Mac, when it next comes
   online, will see the lock has moved and won't push without
   re-taking.

## Troubleshooting

- **"Can't push even after taking lock"** — there are unmerged
  changes upstream. Pull again.
- **"Peer Mac pushed before I noticed the chip"** — git's
  non-fast-forward rejection caught it; resolve via
  [resolve-conflict.md](resolve-conflict.md).
- **"Lock loops between Macs"** — discuss the cadence with your
  team / yourself. The lock is cooperative; if both sides keep
  taking it, neither pushes consistently.

## See also

- [decisions/0012-cooperative-writer-lock.md](../../decisions/0012-cooperative-writer-lock.md).
- [explain/cooperative-locking.md](../../explain/cooperative-locking.md).
- [reference/file-formats/active-toml.md](../../reference/file-formats/active-toml.md).
