# Handle a sandboxed app

## Goal

Decide what to do when Sojourn detects a sandboxed app (Mac App Store,
Apple system app, or third-party app shipping a sandbox entitlement)
that you'd like to sync preferences for.

## Prereqs

- An app whose preferences live in `~/Library/Containers/<bundle-id>/`
  rather than `~/Library/Preferences/`.
- Familiarity with what Full Disk Access opts into.

## Why sandboxed apps need different handling

Unsandboxed apps store preferences in `~/Library/Preferences/<bundle>.plist`
where any process can read/write them with `defaults`. Sandboxed apps
store them in `~/Library/Containers/<bundle>/Data/Library/Preferences/<bundle>.plist`,
which is gated by macOS TCC. Standard Sojourn (without FDA) cannot
read this path.

## Three options

### 1. Skip — recommended default

Don't sync this app's preferences. Most users care more about dotfiles
+ packages than per-app prefs; skipping a few sandboxed apps is fine.

In the Preferences pane, click *Skip — never track*. Sojourn records
the skip and stops surfacing the app.

### 2. Opt in to FDA — for the sandboxed app you really care about

1. Open Sojourn → Settings → Preferences → Full Disk Access.
2. Read the warning and click *Open System Settings*.
3. macOS opens *Privacy & Security → Full Disk Access*.
4. Toggle Sojourn on. macOS prompts for password.
5. Restart Sojourn.
6. The sandboxed app now appears in the Preferences pane with a *Track*
   button enabled.

Cost: Sojourn now has Full Disk Access. Per
[explain/threat-model.md](../../explain/threat-model.md), Sojourn
doesn't ship any feature that abuses FDA, but the grant is opt-in
because it broadens the trust surface.

### 3. Defer — wait for the v1.x sandboxed-app sync

Sojourn's v1.x scope adds first-class sandboxed-app handling with
finer-grained prompts (audit §1.5 "Discover pane"). If the app isn't
critical, leave it untracked and revisit when v1.x ships.

## Steps for option 2 (FDA opt-in)

1. **Open Settings → Preferences**.
2. Toggle *Enable Full Disk Access*. Read the explanation.
3. Click *Open System Settings*. Toggle Sojourn on in the FDA list.
4. Restart Sojourn (it cannot pick up FDA changes mid-process).
5. The sandboxed app now shows in the Preferences pane.
6. *Track* — flow continues as in
   [track-app.md](track-app.md).

## Verification

- *Settings → Preferences → FDA status* shows *Granted*.
- The app's plist exports cleanly via `defaults read` from inside
  `~/Library/Containers/`.
- A peer Mac (also with FDA granted) imports the plist successfully.

## Troubleshooting

- **"FDA toggle does nothing"** — macOS sometimes silently denies
  the grant. Quit Sojourn fully (Cmd-Q, not just close window) and
  restart.
- **"Some sandboxed apps still grey"** — some apps additionally
  encrypt their preferences (notably some Apple system apps). Sojourn
  cannot decrypt; the app cannot be synced.
- **"Plist diff is huge on every push"** — sandboxed apps with auto-saved
  state often dirty the plist on every launch. Mark as *prompt* tier
  and accept only meaningful diffs.

## See also

- [reference/pref-domains.md](../../reference/pref-domains.md) —
  classification matrix.
- [explain/threat-model.md](../../explain/threat-model.md) — FDA
  trust surface.
- [process/audit-2026-04.md §1.5](../../process/audit-2026-04.md#1-doc-level-inconsistencies)
  — Discover pane / sandboxed-app sync (deferred).
