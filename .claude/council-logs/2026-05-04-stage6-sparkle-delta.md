# Council 2026-05-04 — v0.3 stage 6: Sparkle delta updates

**Triggers (two)**:
1. New external SPM dependency added: `github.com/sparkle-project/Sparkle` 2.9.x.
2. Signing-config / `notarize.yml` change.

## Verdicts

| Member | Decision |
|---|---|
| architect | APPROVE-WITH-CONDITIONS |
| security | APPROVE-WITH-CONDITIONS |
| perf-skeptic | REJECT (initial) → APPROVE-WITH-CONDITIONS (after fixes) |
| ux-critic | APPROVE-WITH-CONDITIONS |
| devil-advocate | APPROVE-WITH-CONDITIONS |

## Conditions accepted in this commit

- **architect/devil-advocate force-unwrap**: `controller!` removed. Two-phase init now bootstraps with a discardable nil-delegate controller, then re-seats with `self` as `updaterDelegate`. `controller` is `var` to enable that single re-seat in init only.
- **architect/perf singleton lazy-init**: `SparkleService.shared` removed. `SparkleService` is now AppStore-owned (`AppStore.sparkleService`). `SojournApp` constructs it eagerly in the `WindowGroup .task` block via `Task.detached(priority: .background)` so the menubar 200ms launch budget is not blocked by `SPUStandardUpdaterController.init`.
- **architect fallback-loop guard**: `hasFallenBackThisSession` flag — second consecutive `deltaUpdateFailedCode` does not recurse; sets `"Update failed twice (delta + full). Try again later."` instead.
- **architect error-domain check**: `nsError.code == 4002` AND `nsError.domain == "SUSparkleErrorDomain"`. Foundation errors with code 4002 cannot trigger the fallback path.
- **architect/perf 30s URLSession timeout**: `feedURLSession(for:)` delegate method implemented, returning a `URLSession` with `timeoutIntervalForRequest = 30`. Foundation 60s default no longer applies to appcast fetches.
- **security placeholder fail-loud**: `notarize.yml` runs `grep -q PLACEHOLDER Sojourn/Info.plist` before signing. Build aborts with `exit 1` if `SUPublicEDKey` placeholder still present.
- **security empty-key fail-loud**: `notarize.yml` runs `[ -s "$KEY_FILE" ]` after the 1Password read. Build aborts if the secret loaded empty.
- **security key shred**: `trap 'rm -P -f "$KEY_FILE"' EXIT` (was `rm -f`) per ADR-0016 ephemeral key handling.
- **architect appcast URL mismatch**: `SUFeedURL` now points at `https://github.com/Bizarre-Industries/Sojourn/releases/latest/download/appcast.xml` (GitHub's "latest" alias). `notarize.yml` uploads `appcast.xml` to the release; no separate CDN/redirect needed.

## Conditions deferred (tracked as v0.3.0 tag pre-flight)

- **ADR-0025 corrupt-delta VM smoke**: explicitly approved by maintainer for tag pre-flight. Tag-time agent must run the smoke against a clean Tahoe VM before the `v0.3.0` push.
- **architect SparkleService unit tests**: deferred. The delegate fallback path is currently exercised only via the structural `swift build` + `xcodebuild build` clean. SPM exclude (Sparkle binaryTarget needs AppKit bundle) makes `swift test` insufficient. Tests will land alongside the next Sparkle-touching change or in v0.4.
- **ux statusMessage surfacing**: `statusMessage` is observable but not yet wired to a view. Sparkle's stock progress sheet does not bridge custom delegate strings; a Sojourn-owned status row (Diagnostics pane footer) is the right home. Track in v0.4 backlog.
- **ux i18n for delegate strings**: deferred per stage 5 deferred i18n pass (broader scope).
- **devil-advocate Sparkle tarball SHA pin**: deferred. Workflow tag-pins `2.9.1` but does not pin the tarball SHA. Acceptable for now; revisit if tarball-swap becomes a real threat (Sparkle's own release pipeline is the primary trust anchor).
- **devil-advocate cosign verify of Sparkle XCFramework**: deferred. SPM `binaryTarget` checksum guards build reproducibility; cosign would add supply-chain trust. Track in v0.4.
- **architect prerelease tag handling**: workflow guard `if: "!contains(github.ref, '-')"` skips Sparkle steps on `-beta.N` tags. Beta users will not auto-upgrade via Sparkle until the next non-prerelease tag. Documented; intentional.

## Files

- `Sojourn/Services/SparkleService.swift` (new)
- `Sojourn/Store/AppStore.swift` (gains `sparkleService` + init)
- `Sojourn/App/SojournApp.swift` (Task.detached `start()` + menubar Check for Updates command via `storeBox.store?.sparkleService`)
- `Sojourn/Info.plist` (SUFeedURL → GitHub releases latest, SUPublicEDKey placeholder, SUEnableAutomaticChecks, SUScheduledCheckInterval=86400)
- `project.yml` (Sparkle SPM dep, target dep, CURRENT_PROJECT_VERSION 25 → 26)
- `Package.swift` (exclude `Services/SparkleService.swift` from SPM; Sparkle requires AppKit bundle)
- `.github/workflows/notarize.yml` (placeholder fail, empty-key fail, rm -P shred, generate_appcast steps)
- `appcast.xml` (empty channel scaffold)

## Verification

- `swift build` → clean.
- `xcodegen generate` → success.
- `xcodebuild -scheme Sojourn -destination 'platform=macOS,arch=arm64' build` → BUILD SUCCEEDED (Sparkle 2.9.1 SPM resolves on macOS 26).
- `xcodebuild test -scheme Sojourn -destination 'platform=macOS,arch=arm64' -only-testing:SojournTests` → TEST SUCCEEDED.
- `gitleaks dir . --no-banner` → no leaks (placeholder pubkey contains no entropy that triggers rules).

## Tag pre-flight checklist (must complete before pushing `v0.3.0`)

- [ ] Replace `SUPublicEDKey` placeholder in `Sojourn/Info.plist` with the real EdDSA pubkey from `op://Bizarre-Industries/sojourn-sparkle-eddsa/public-key`.
- [ ] Run corrupt-delta smoke on a clean Tahoe VM per ADR-0025.
- [ ] Verify `https://github.com/Bizarre-Industries/Sojourn/releases/latest/download/appcast.xml` resolves once the first delta-bearing release ships.
- [ ] Re-verify Sparkle 2.9.x is still the latest stable Sparkle line.
