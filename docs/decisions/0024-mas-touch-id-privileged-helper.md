# 0024 — mas Touch-ID via privileged helper installed by `SMAppService`

- **Status**: Accepted
- **Date**: 2026-05-03
- **Deciders**: Maintainer (skalghazali); Sojourn council (architect,
  security, devil-advocate, perf-skeptic, ux-critic).

## Context

CVE-2025-43411 (mas-cli release notes 4.0; lessons.md "mas requires
sudo on macOS 14.8.2+ / 15.7.2+ / 26.1+") forces `mas install` and
`mas upgrade` to run with elevated privileges on current macOS. v0.2
shipped an `osascript with administrator privileges` flow that
prompts for the user's password on every install, which is hostile
UX for users maintaining multi-machine fleets where Sojourn drives
many App Store installs in one session.

`docs/process/plans/v0.3-plan.md` §"Why privileged-helper Touch-ID"
locks the architecture: a privileged helper installed once via
`SMAppService` (post-macOS 13 path) at
`/Library/PrivilegedHelperTools/industries.bizarre.Sojourn.helper`,
asked for once via Authorization Services, after which all
`mas install` / `mas upgrade` calls go through the helper without
re-prompting until next reboot or explicit user revocation.

`Casks/sojourn.rb` already declares `uninstall delete:` for the
helper path so cask uninstall removes the helper alongside the app.

## Decision

Sojourn ships a privileged helper as a dedicated Xcode target named
`MasHelper`, installed via `SMAppService.daemon(plistName:)` (the
modern post-macOS 13 entry point that supersedes
`SMJobBless`). Bundle id `industries.bizarre.Sojourn.helper`. The
helper exposes an XPC listener on
`industries.bizarre.Sojourn.helper.mach` that:

- Validates the connecting client against `SMAuthorizedClients` —
  the requirement string pins Sojourn's anchor + leaf certificate so
  only an Apple-notarized Sojourn build of matching identity can call
  in.
- Wraps `mas install <id>` and `mas upgrade [<id>]` invocations.
- Returns the subprocess exit status, stdout, and stderr to the
  caller as XPC reply.
- Logs every invocation to OSLog with subsystem
  `industries.bizarre.Sojourn.helper` for forensic recovery.

The Sojourn app side is `Sojourn/Services/MasHelperClient.swift` (XPC
client) plus `Sojourn/Services/MasService.swift` (existing surface,
swapped to call the helper instead of invoking `mas` directly).

Touch-ID prompt fires once at helper-install time via
`SMAppService.daemon(plistName:).register()` — Apple's
LaunchServices presents the standard system prompt for the user to
authorize installing the helper into
`/Library/PrivilegedHelperTools/`. After that single install-time
prompt, subsequent `mas install` / `mas upgrade` calls go through
XPC with `SMAuthorizedClients` validation + per-connection
code-signing validation only — NO per-call AuthorizationRef
prompt. The helper runs as root once installed; client validation is
the gate, not a renewed AuthorizationRef. The user revokes by
disabling Sojourn in System Settings → General → Login Items
(SMAppService entry), which unregisters the helper.

## Consequences

### Positive

- One AuthorizationRef per session covers every `mas` install/upgrade,
  matching the user's expectation when they fleet-install N apps.
- Helper bundle is signed + notarized in `notarize.yml` alongside the
  app; uninstall path is `Casks/sojourn.rb::uninstall delete:` for
  the helper file.
- `SMAuthorizedClients` certificate-pinning means a malicious app
  cannot connect to the helper to escalate privileges; only a
  legitimate Sojourn build can.
- Replaces the v0.2 `osascript with administrator privileges` per-call
  prompt with single-prompt UX matching the value prop
  ("multi-machine fleet" implies many installs per session).

### Negative

- New Xcode target + XPC + signing surface; CI complexity grows.
  Helper bundle must pass `spctl --assess --verbose=4` independently
  of the app.
- `SMAppService.daemon` requires macOS 13+. macOS 26 floor (per
  CLAUDE.md invariant 10) makes this a non-issue, but documented
  here for posterity.
- Helper persists across app uninstall unless the cask uninstall
  stanza removes it. Tested in v0.3 release smoke check.
- Authorization Services prompt copy is system-controlled; users see
  "Sojourn wants to make changes" rather than custom messaging.
  Acceptable.

### Neutral

- Per-machine override format (machines.toml) unaffected.
- `mas signin` for unowned apps is still broken; Sojourn surfaces
  "Open in App Store" flow for that case (lessons.md entry).

## Alternatives considered

- **Always prompt per install** (status quo) — rejected. Hostile UX
  for fleet installs; the v0.2 placeholder, never the v0.3 target.
- **Run Sojourn as root via `sudo` wrapper** — rejected. Catastrophic
  blast radius; violates least-privilege; would require disabling SIP
  or installing Sojourn into `/usr/local/sbin`.
- **Use `sudo` with a sudoers entry granting passwordless `mas`** —
  rejected. Editing /etc/sudoers from an app installer is hostile and
  fragile (softwareupdate rewrites pam.d, NOPASSWD entries get
  reverted by management profiles, etc. — see lessons.md "Apple's
  docs say it works, ship it").
- **`SMJobBless` (legacy)** — rejected. Deprecated path, not the
  recommended modern API. `SMAppService.daemon` is the post-macOS 13
  path and is what Apple's documentation directs toward.
- **Skip Touch-ID, lean on App Store-managed install** — rejected.
  App Store doesn't support fleet/scripted install of free apps; the
  whole reason for `mas` in the toolchain is to bypass that.

## Council 2026-05-03 amendments

### Signing & embed protocol

- Helper bundle path inside `Sojourn.app`:
  `Contents/Library/LaunchDaemons/industries.bizarre.Sojourn.helper`.
- `notarize.yml` ordering: helper signed first with
  `--options=runtime` and Developer ID Application identity; outer
  app re-signed after embed; both pass
  `spctl --assess --verbose=4` independently.
- `SMAuthorizedClients` requirement string template (in helper's
  `Info.plist::SMAuthorizedClients` array) — substituted at build
  time with Bizarre Industries team ID for `<TEAMID>`:
  ```
  anchor apple generic
    and identifier "industries.bizarre.Sojourn"
    and certificate 1[field.1.2.840.113635.100.6.2.6] /* Developer ID intermediate */
    and certificate leaf[field.1.2.840.113635.100.6.1.13] /* Developer ID Application */
    and certificate leaf[subject.OU] = "<TEAMID>"
  ```
  Mirrored in `Sojourn.app/Info.plist::SMAuthorizedClients` for the
  helper-trusts-app direction.

### XPC API contract & per-connection validation

- **Per-connection validation.** Helper's XPC listener calls
  `NSXPCConnection.setCodeSigningRequirement(_:)` (macOS 13+) on
  every incoming connection with the same requirement string.
  `SMAuthorizedClients` is install-time-only and does NOT gate
  XPC connections.
- **Argv discipline.** App Store IDs cross XPC as `UInt64`, never
  `String`. Helper rejects values that fail `UInt64(stringValue)`
  round-trip. `Process` invoked with
  `arguments: ["install", String(id)]` — argv array, never a
  concatenated shell-interpreted string.
- **Per-call authorization (when needed).** If a future call needs
  fresh authorization (e.g., `mas signout` rotating the App Store
  account), the helper invokes `AuthorizationCopyRights` with
  `kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed`
  for a custom right (`industries.bizarre.Sojourn.helper.<action>`)
  — the system enforces grace; the helper does NOT cache an
  `AuthorizationRef`. v0.3 `mas install` / `mas upgrade` does NOT
  use this path (helper-install-time prompt covers it); the
  pattern is documented for future calls that need step-up auth.

### Helper subprocess timeout

Helper-side enforces a 600s hard cap on `mas install` /
`mas upgrade` (snapshot tier per JobRunner timeout policy in
`v0.3-plan.md` §"Hard decisions"). On hang the helper returns
`MasError.timedOut` to the XPC client. AuthorizationRef remains
valid for the next call (helper restart preserves session via
launchd; XPC client retries once on `xpc_connection_invalid`).

### Helper authorization status surface (UX)

PackagesPane renders a status row "Touch-ID install helper active"
with version + register-time + a "Revoke" button. Revoke calls
`SMAppService.daemon(plistName:).unregister()` and removes the
helper bundle. The row disappears once the helper is unregistered;
the next `mas install` triggers a re-install prompt. Closes the
"silent calls feel like surveillance" UX gap.

### Council log

`/Users/binghzal/Developer/Sojourn/.claude/council-logs/2026-05-03-v0.3-adr-batch.md`.
