# Discover pane

> **Audit driver**: closes
> [process/audit-2026-04.md §1.5 / §4.2.9 / §4.2.10](../process/audit-2026-04.md)
> + [process/open-questions.md](../process/open-questions.md) §4. Lands in
> v1.1 (Phase 12 §1.5 / §4.2.9 / §4.2.10 deferred).

The v0.1 design PDF (page 36) introduced a **Discover** pane backed by a
live `cfprefsd` watcher — record every preference change anywhere on the
system, ask the user later which to keep. Sojourn does **not** ship that.
Discover ships in v1.1 as a **bounded, consensual record-session mode**.

## Why not the live watcher

`cfprefsd` is the system-wide preferences daemon. A live watcher captures
*every* preference write across the user's whole session — Mail account
configuration, Safari per-site settings, Spotlight indexing exclusions
(which leak project structure), Dock layout, every UI toggle the user
clicks. "Redaction" of that stream is a multi-year ML / heuristic problem
nobody has shipped a credible solution for.

Three failure modes:

1. **Privacy leak.** When redaction misses, user data lands in the data
   repo's git history. Reverting a leak from public git history is hard.
2. **Inadvertent capture.** "I clicked something to test" turns into
   "Sojourn is now syncing my Mail.app preferences." User mental model
   doesn't match reality.
3. **Unbounded scope.** The user can't know what was captured without
   reading every preference write. There's no way to make this scale.

The audit's three options ((a) opt-in-per-domain / (b) global-with-redaction
/ (c) something else) reduce to (c). Discover-as-record-session is (c).

## What Discover does

> **In v1**, Discover is not present. The Track-app pane covers the
> explicit-track case for known-domain preferences. v1.1 introduces
> Discover as the surface for *finding* unknown domains.

User flow:

1. User opens Discover pane → clicks **Start recording**.
2. Sojourn snapshots the current state of all currently-tracked domains
   plus a **whitelist of recordable domains** that ships with the app
   (see below). Snapshots use `defaults read <domain>` and store the
   plist payload in memory.
3. User makes the changes they want to capture (e.g., open Terminal →
   adjust font, add a profile).
4. User returns to the Discover pane → clicks **Stop recording**.
5. Sojourn `defaults read`s the same whitelist again, diffs against the
   start-of-recording snapshot, and shows a structured per-key diff
   grouped by domain:
   - `com.apple.Terminal`
     - changed `Default Window Settings`: `"Basic"` → `"Pro"`
     - added profile `"work"`
   - `com.googlecode.iterm2`
     - changed `New Bookmarks[0].Background Color`: `…` → `…`
6. User reviews and **selectively commits** keys to tracked preferences
   — same path as the existing Preferences pane.

## Whitelist of recordable domains

Discover only diffs domains in the recordable whitelist. The whitelist
is a finite, app-shipped list updateable via OTA registry refresh
(audit §3.2.5 BackendRegistry path, same mechanism as
`dotfile_owners.toml` and `applications/*.toml`).

Initial whitelist (v1.1):

- Terminal emulators: `com.apple.Terminal`, `com.googlecode.iterm2`,
  `com.mitchellh.ghostty`, `com.github.wez.wezterm`, `dev.warp.Warp-Stable`
- Editors: `com.microsoft.VSCode`, `com.todesktop.230313mzl4w4u92` (Cursor),
  `com.jetbrains.*`, `com.sublimetext.4`
- Developer tools: `com.charlessoft.pasteboard`, `com.runningwithcrayons.Alfred`,
  `com.raycast.macos`, `pl.maketheweb.cleanshotx`, `com.macpaw.CleanMyMac5`
- Shell-adjacent UI: `com.googlecode.iterm2`, `org.gpgtools.gpgmail`

Explicitly excluded from the whitelist:

- Any system domain (`com.apple.iChat`, `com.apple.mail`, `com.apple.Safari`,
  `com.apple.Spotlight`, `com.apple.dock`).
- Any keychain-backed preference domain.
- Any sandboxed-container preference (FDA-gated; out of scope per
  [reference/preference-sync.md](../reference/preference-sync.md) Layer 4).

Users can extend the whitelist via Settings → Preferences → Discover →
"Recordable domains" with explicit per-domain opt-in. Adding a system
domain triggers a confirmation dialog calling out the privacy implications.

## Properties this design has

- **Bounded in time.** Recording window has a start and a stop. No
  always-on watcher.
- **Bounded in domain scope.** Whitelist-only by default; user-extensible
  with explicit opt-in.
- **No redaction problem.** Diff is structured plist data the user
  reviews item-by-item before commit.
- **No cfprefsd watcher.** `defaults read` snapshots before/after are
  sufficient; cfprefsd internals are not used.
- **Matches the user's mental model.** "I just changed something I want
  to sync" is the actual user story.

## What Discover does not do

- Capture changes outside the recording window. (If the user forgot to
  click Start, the change isn't captured. They restart the recording
  and redo it. The alternative is the always-on watcher; rejected.)
- Capture changes in non-whitelisted domains. (User extends the
  whitelist explicitly.)
- Auto-commit. Every captured key surfaces in the diff for explicit
  review, same as the Preferences pane's existing flow.
- Replace the Preferences pane's Track-app surface. Discover is for
  *finding* domains; Preferences pane is for *managing* the ones you
  found.

## Discover ↔ Preferences relationship

Discover is a **session mode of the Preferences pane**, not a separate
top-level pane. The Discover surface lives under
*Preferences → Discover* (tab or toolbar mode toggle). When recording
ends and the user commits keys, those keys move into the Preferences
pane's normal tracked-domain surface.

This collapses the audit's §4.2.10 question ("Is Discover a session-mode
of Preferences or its own thing?") to: session-mode.

## See also

- [reference/preference-sync.md](../reference/preference-sync.md) —
  the four-layer transport that Discover ultimately commits into.
- [reference/pref-domains.md](../reference/pref-domains.md) — domain
  classification and cfprefsd relaunch behaviour.
- [decisions/0002-no-symlink-preferences.md](../decisions/0002-no-symlink-preferences.md)
  — `defaults` round-trip is the only first-class transport.
- [process/open-questions.md](../process/open-questions.md) §4 — the
  decision record for why Discover is not the live watcher.
