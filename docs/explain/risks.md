# Risks and unknowns

Technical risks that could kill the project or require major rework, ordered
by severity.

## 1. `cfprefsd` gets stricter

Apple could further lock down `~/Library/Preferences` access in a future
macOS release (Tahoe 27 is the next wildcard). If `defaults import` starts
requiring additional entitlements or fails for unsandboxed callers,
Sojourn's whole preference-sync story degrades.

Mitigation: classification system means dotfile + package sync keeps working
even if pref sync breaks. Watch Apple security guides at each WWDC. Have a
plan to ship "preferences as declarative `defaults write` scripts" as a
fallback. See [reference/preferences.md](../reference/preferences.md).

## 2. Homebrew behavior changes

Sojourn now bets on Brewfile / `brew bundle` as the single package backend
([decisions/0018-drop-mpm-for-brew-bundle.md](../decisions/0018-drop-mpm-for-brew-bundle.md)).
If Homebrew changes `brew bundle`, `brew outdated`, or JSON surfaces, package
sync can break across many managers at once.

Mitigation: keep parsing fixture-backed, surface per-command failures loudly,
never hash exact subprocess stdout, and prefer documented Brewfile behavior
over scraping human output.

## 3. `swift-subprocess` is pre-1.0 and requires Swift 6.2-era tooling

The API could change. Mitigation: wrap it in `SubprocessRunner` so swapping
to raw `Process + Pipe + AsyncStream` is an internal refactor.

## 4. Homebrew's self-update behaviour changes

The JSON API refresh was 1 day, then 7 days (PR #21262, Dec 2025);
`brew outdated` output format flapped in bug #20976 (Nov 2025, unresolved).
Parsers break when brew changes output. Mitigation: treat backend output as
advisory and don't write tests that hash exact strings.

## 5. chezmoi's `diff`/`status` are not stable structured formats

Hybrid diff (#677) and `MM` vs `M ` ambiguity (#2635, #4180) are unresolved.
Mitigation: render `diff` verbatim; parse `status` with a regex but treat
it as a display signal only — the ground truth is `chezmoi apply --dry-run`
when we actually care.

## 6. gitleaks false positives on new-user dotfiles

Entropy rules fire on base64 UUIDs, test fixtures, example keys. User
clicks "Commit anyway" and learns to ignore the prompt. Mitigation: ship
conservative rules; verified-provider findings (AWS / GitHub PAT / OpenAI /
Stripe live) disable the "Commit anyway" button for 5s and show a red
banner.

## 7. GitHub Device Flow per-app enablement

Required since March 2022. The OAuth App must have the checkbox ticked, and
Apple has no equivalent way to let the app switch dynamically. Sojourn owns
and maintains the OAuth App. Mitigation: BYO remote is the default; device
flow is opt-in convenience, so if the OAuth App is ever revoked or
rate-limited, app core keeps working.

## 8. Notarization of bundled Go binaries

`gitleaks` and `age` are straightforward but each macOS release has broken
someone's stapling. Mitigation: re-sign on the Sojourn build machine with
`--options=runtime` every release; CI asserts that
`spctl --assess --verbose=4 Sojourn.app` passes on a Gatekeeper-clean VM.

## 9. Conflict on concurrent writes deferred to v2

Two Macs push at the same time → git conflict, app refuses to pull until
user resolves. Mitigation: cooperative `active.toml` writer lock (see
[reference/sync-model.md](../reference/sync-model.md)); loud UI messaging;
manual conflict resolution via embedded diff pane. Not ideal; not fatal.

## 10. TCC / Full Disk Access surface

Future macOS may gate `~/Library/Application Support` for third-party apps
(Sonoma started gating `~/Library/Containers`). Mitigation: minimize FDA
asks; only request when the user opts into sandboxed-app pref sync;
canary-probe `/Library/Preferences/com.apple.TimeMachine.plist` to detect
FDA status.

## 11. APFS timestamp semantics are unreliable

atime isn't authoritative; orphan detection depends on composite signals.
Mitigation: never auto-delete; always move to Trash; log every action.
See [reference/cleanup.md](../reference/cleanup.md).

## 12. User data loss via buggy `chezmoi apply`

`--force` overwrites local edits. Mitigation: always pre-snapshot to
`.sojourn/backups/` before any destructive operation; retention 30d; undo
log.

## Unknowns flagged for re-verification

- `.com` apex availability for `sojourn` — not checked. WHOIS before
  publicizing the name.
- Tahoe-specific APFS atime behaviour — no public documentation suggests
  change, but not independently confirmed.
- Cork's exact license model verified per
  [process/audit-2026-04.md §1.2](../process/audit-2026-04.md#1-doc-level-inconsistencies):
  GPL-3 with paid binaries via Paddle, no Commons Clause.
