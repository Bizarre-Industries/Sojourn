# Trade-offs

Honest list of what Sojourn does not do and why. Sourced from the
v0.1 risk register and v1 scope cut in
[`docs/_legacy_architecture.md` §13–§15](../_legacy_architecture.md).
Tracking continues in [process/future.md](../process/future.md).

## Capabilities Sojourn ships in v1

The full v1 scope is in
[process/implementation-plan.md](../process/implementation-plan.md).
Headline:

- Package sync via `mpm` for brew, cask, mas, pip, pipx, npm, cargo, gem.
- Dotfile sync via `chezmoi` with templating, age encryption,
  per-machine overrides.
- App-preference sync for **unsandboxed plists only** —
  `defaults export/import` round-trip.
- Explicit push/pull with cooperative writer lock.
- BYO git remote (primary). Optional GitHub Device Flow.
- Auto-update with 7-day cooldown + tier gating + OSV bypass.
- Pre-commit secret scan via bundled gitleaks.
- Orphan detection via bundle-ID reconciliation + curated dotfile
  registry.
- First-run bootstrap via signed Homebrew `.pkg` + brew-installed
  `mpm` / `chezmoi`.
- Menu bar extra + main window.
- Notarized DMG. GPL-3.0-or-later.

## Deferred to a later release

These ship eventually but not in v1:

- **Sandboxed-app preference sync** (e.g. App Store apps that live in
  `~/Library/Containers/`). Requires Full Disk Access plus more careful
  cfprefsd choreography. Audit §1.5 also flags a "Discover pane"
  cfprefsd watcher that depends on this work.
- **Concurrent-write conflict resolution.** Three-way merge with
  per-file timestamps. v1 ships the cooperative writer lock instead
  ([decisions/0012-cooperative-writer-lock.md](../decisions/0012-cooperative-writer-lock.md)).
- **`pnpm` support.** mpm doesn't cover it; needs the plugin protocol
  ([decisions/0013-out-of-process-plugins.md](../decisions/0013-out-of-process-plugins.md)).
- **Full VT100 terminal pane** (`SwiftTerm`-backed advanced tab).
- **Headless LaunchAgent.** `SMAppService.agent` so Sojourn can run
  background checks while the GUI is quit.

## Deferred indefinitely

Out of scope for the foreseeable future:

- **Mac App Store distribution.** App Sandbox is incompatible with
  subprocess invocation of `brew`, `mpm`, `chezmoi`, `defaults`. Direct
  notarized-DMG distribution is the model.
- **Windows or Linux.** Sojourn is macOS-native by design
  ([decisions/0014-no-linux-no-helling-plugin.md](../decisions/0014-no-linux-no-helling-plugin.md)).
  The core dependencies (`defaults`, FDA, cfprefsd, Keychain) don't
  exist there.
- **Cloud backend hosted by Sojourn.** Local-only; user's git remote is
  the only persistence. No telemetry, no crash dumps, no install events
  sent anywhere.
- **Team / org sync.** Single-user only. Multi-user would need
  authentication, ACLs, audit logs — a different product.
- **Mobile companion.** Sojourn is a desktop sync tool, not a
  cross-device fleet manager.

## Risks Sojourn cannot fully mitigate

These are real and the mitigations are partial:

1. **`cfprefsd` gets stricter.** Apple may further lock down
   `~/Library/Preferences` access. *Mitigation*: classification system
   keeps dotfile + package sync working even if pref sync breaks. Watch
   Apple security guides every WWDC. Fallback plan: ship preferences
   as declarative `defaults write` scripts. See
   [reference/preference-sync.md](../reference/preference-sync.md).
2. **mpm bus factor.** Single maintainer. *Mitigation*: keep
   `MPMService` surface small enough that each method can be
   reimplemented against the underlying managers within ~1 week.
3. **`swift-subprocess` is pre-1.0.** API may change. *Mitigation*:
   wrap in `SubprocessRunner` so swapping to raw `Process + Pipe +
   AsyncStream` is an internal refactor.
4. **Homebrew output flaps.** PR #21262 (Dec 2025) bumped the JSON API
   refresh to 7 days; bug #20976 (Nov 2025) shows `brew outdated` output
   format flapping. *Mitigation*: treat all backend output as advisory;
   surface per-manager `errors[]`; never hash exact strings in tests.
5. **chezmoi `diff` / `status` are not stable structured formats.**
   *Mitigation*: render `diff` verbatim; treat `status` regex output as
   display-only; ground truth is `chezmoi apply --dry-run`.
6. **gitleaks false positives.** Entropy rules fire on UUIDs, fixtures,
   examples. Users learn to ignore the prompt. *Mitigation*: ship
   conservative rules; verified-provider findings disable *Commit
   anyway* for 5 seconds and show a red banner.
7. **GitHub Device Flow requires per-app enablement.** *Mitigation*:
   BYO remote is the default; Device Flow is opt-in convenience. If
   the OAuth App is rate-limited or revoked, app core keeps working.
8. **Notarization of bundled Go binaries.** Each macOS release has
   broken stapling for someone. *Mitigation*: re-sign every release
   under `--options=runtime`; CI asserts `spctl --assess` on a
   Gatekeeper-clean VM.
9. **Concurrent-write conflicts deferred.** Two Macs push at once →
   git conflict → app refuses to pull until manual resolution.
   *Mitigation*: cooperative `active.toml` writer lock; loud UI
   messaging; embedded diff pane.
10. **TCC / Full Disk Access surface.** Sonoma started gating
    `~/Library/Containers/`; Tahoe may go further. *Mitigation*:
    minimize FDA asks; only request when the user opts into
    sandboxed-app pref sync; canary-probe to detect FDA status.
11. **APFS atime is unreliable.** Default mount is non-strict atime.
    *Mitigation*: never auto-delete; always move to Trash via
    `NSFileManager.trashItem`; log every action.
12. **`chezmoi apply --force` overwrites local edits.** *Mitigation*:
    pre-snapshot to `.sojourn/backups/` before any destructive op;
    30-day retention; undo log. Audit §2.2.3 promotes Phase 12 to swap
    `--force` for `chezmoi merge` on text dotfiles.

## Things Sojourn could do but chose not to

- **Auto-rebase on conflict.** Surfacing conflict to the user is a
  feature, not a bug. Auto-rebase hides corruption.
- **Run `chezmoi apply --force` without dry-run preview.** The 99%
  case is "user already approved"; the 1% case is "user gets a
  surprise overwrite". Always preview.
- **Cache JSON output across runs.** Stale cache > slow command.
- **Three-way auto-merge of plists.** Plist semantics are not
  line-mergeable; even the chezmoi maintainers say so.
- **Embed `client_secret` for GitHub OAuth Apps.** Forever lockout if
  ever leaked. Device Flow is `client_id`-only.

## See also

- [process/future.md](../process/future.md) — active deferred-work
  log; reads more like a backlog than a manifesto.
- [process/audit-2026-04.md](../process/audit-2026-04.md) — gap
  analysis driving v1 → v1.x.
- [process/implementation-plan.md](../process/implementation-plan.md)
  "Out of scope" — phase-level scope cuts.
