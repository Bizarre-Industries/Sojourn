# Council Log: Debug Entitlements for Hosted Xcode Tests

Date: 2026-05-04
Trigger: signing configuration changed (`project.yml`, regenerated Xcode project, and app entitlements).

## Proposal

Hosted Xcode unit tests need to inject into `Sojourn.app`. The previous Debug app used the release entitlement file with `com.apple.security.get-task-allow` forced to `false`, which blocks debugger/XCTest attachment. Removing `TEST_HOST` and `BUNDLE_LOADER` was tested and rejected because the Xcode test bundle then failed to link against Sojourn symbols.

Split app entitlements by configuration:

- Debug: `Sojourn/SojournDebug.entitlements` with `get-task-allow=true` and the existing Apple Events exception.
- Release: `Sojourn/Sojourn.entitlements` with `get-task-allow=false`.
- `project.yml` sets `CODE_SIGN_ENTITLEMENTS` per configuration and `Sojourn.xcodeproj` was regenerated.
- `Package.swift` excludes the debug entitlement so SwiftPM does not warn about an unhandled resource.
- Release docs explicitly say the full UI-test gate is not passed when local automation/TCC prevents UI-test initialization.

## Verification

- `plutil -lint Sojourn/Sojourn.entitlements Sojourn/SojournDebug.entitlements MasHelper/MasHelper.entitlements` passed.
- `swift build` passed.
- `swift test` passed: 147 tests.
- Focused hosted Xcode unit test passed with local Apple Development signing: 147 tests.
- `make ci-local` passed: `actionlint`, `gitleaks`, `pinact`, `zizmor`, expiry validation, and advisory Swift lint/format checks.
- Full local `make xcodebuild` reached `SojournUITests` setup and failed only with `Timed out while enabling automation mode`; this is a local macOS UI automation/TCC gate and is not counted as release success.

## Architect

Decision: approve with conditions.

Dissents:

- Commit `Sojourn/SojournDebug.entitlements`; otherwise Debug signing breaks on clean checkout.
- Update the stale comment in `Sojourn.entitlements` that described Debug attachability as a runtime override.
- Do not claim the full UI-test release gate has passed until it passes on a machine with working UI automation permissions.

Risks:

- Release accidentally pointing at the Debug entitlement would be a high-severity notarization/security failure.
- Hosted tests can still be misdiagnosed when the actual issue is signing or local automation permission state.

Resolution: conditions accepted. The new entitlement is included, the comment was updated, and this log records the remaining UI automation blocker.

## Security

Decision: approve with conditions.

Dissents:

- Do not stage unrelated untracked `.codex/hooks` files with this signing change; one hook would weaken the gitleaks invariant if committed as-is.

Risks:

- Debug deliberately allows debugger attach/code injection; acceptable for hosted tests, but accidental Debug distribution would be high impact.
- The existing Apple Events exception remains in Debug, but this does not broaden Release because Release still uses `Sojourn.entitlements`.

Resolution: unrelated `.codex` files are excluded from staging. Release still uses `get-task-allow=false`.

## Devil's Advocate

Decision: approve with conditions.

Dissents:

- Longer term, an unhosted Xcode test target or a `SojournCore` target may age better than hosted service-heavy unit tests.
- If entitlements grow, a single entitlement file plus config-specific base entitlement injection may age better than duplicated entitlement files.
- This commit must not be treated as closing the full v0.3 release gate.

Risks:

- Missing the new entitlement file would break Debug builds.
- Future summaries could blur focused Xcode unit success into full UI-test success.
- Repo layout docs can drift if they list only the release entitlement.

Resolution: the new entitlement is included, release-gate language remains explicit, and `docs/reference/repo-layout-app.md` now lists both entitlement files.

## Performance Skeptic

Decision: approve with conditions.

Dissents:

- Commit the new Debug entitlement file with the generated project/config changes.
- Do not record the full local UI-test gate as passed while it still fails at local automation/TCC setup.

Risks:

- No runtime scaling path is introduced. Added signing work is constant-time per app signing.
- Missing the committed Debug entitlement costs one failed Debug signing/test setup on any clean machine.

Resolution: conditions accepted.

## UX Critic

Decision: approve with conditions.

Dissents:

- The release doc needed an executable recovery path for the automation-mode timeout.
- The release entitlement comment needed to reflect the new Debug/Release split.

Risks:

- A maintainer under release pressure could otherwise run unit-only tests and not know how to unblock the full UI-test gate.
- A future maintainer could read stale entitlement comments and undo the split.

Resolution: release docs now name `sudo xcrun automationmodetool enable-automationmode-without-authentication`, the System Settings Accessibility check, and rerunning `make xcodebuild`; the entitlement comment was updated.

## Verdict

Approved to commit after pre-commit gates pass, with the explicit caveat that v0.3 is not release-ready until the full UI-test gate passes on a machine with working local UI automation permissions or equivalent CI evidence.
