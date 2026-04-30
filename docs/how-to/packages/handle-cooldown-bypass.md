# Handle a cooldown bypass

## Goal

Decide what to do when Sojourn surfaces a package update that's still
within the cooldown window. Two flavours: deliberate manual bypass and
automatic OSV-advisory bypass.

## Prereqs

- A package update is available.
- The Packages pane is showing it as *In cooldown · N days remaining*.

## Steps — manual bypass

1. **Click the package** in the Packages pane.
2. **Read the version-bump diff** — Sojourn shows release notes
   from the manager (where available) plus the version delta.
3. **Click *Bypass cooldown***. Sojourn shows a confirmation:

   > Tier B, 3 days into 7-day cooldown.
   >
   > Reason for bypass (optional): _______________
   >
   > Cancel · Bypass and update

4. **Type a reason** (recorded in History) and *Bypass and update*.
5. The update proceeds via `mpm restore` for that single package.
6. The reason is logged in the History pane and `history.db`.

## Steps — automatic OSV bypass

If OSV / GHSA has published an advisory for the **currently installed
version**, Sojourn auto-bypasses the cooldown for the upgrade. The UI
shows a banner:

> ⚠️ Advisory bypass — installed version of `axios@1.14.0` has
> CVE-2026-NNNNN. Upgrading to 1.14.2 (cooldown skipped).

No user action required; the update lands automatically. The bypass
is logged with `initiator = 'osv-bypass'` in `history.db`.

## When to bypass manually

- The cooldown is impeding work and you've verified the upstream
  release notes / changelog yourself.
- A critical bug fix not yet OSV-published.
- Intentional opt-in to bleeding edge for a specific package.

## When NOT to bypass

- The cooldown was set up for a reason; bypass casually = bypass
  every time = no protection.
- "I just want the new version" without reading the release notes.
- For Tier-E (global npm) packages — the 14-day cooldown exists
  because npm has the highest attack surface.

## Verification

- The package shows the new version installed.
- History pane logs the bypass with the reason and initiator.
- The cooldown clock for the **new** version starts at install time.

## Troubleshooting

- **"Bypass button greyed out"** — the package is part of an
  ecosystem with `auto = false` (Tier C/D — user-prompt only).
  Approve the regular update prompt instead.
- **"OSV bypass didn't fire for a known CVE"** — Sojourn fetches
  daily; check Settings → Sync → Background refresh interval.
  Force refresh via *Settings → Sync → Refresh now*.

## See also

- [reference/cooldown-policy.md](../../reference/cooldown-policy.md)
  — full tier ladder + OSV-bypass semantics.
- [explain/tier-model.md](../../explain/tier-model.md) — rationale.
- [decisions/0003-cooldown-7-days.md](../../decisions/0003-cooldown-7-days.md).
