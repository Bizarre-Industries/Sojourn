# Council Log: v0.4 Stage 6 Release Hardening

Date: 2026-05-05

## Trigger

Council fired because the Stage 6 commit candidate touches
`.github/workflows/notarize.yml` and deletes more than 100 lines in one
commit. No change touches `Sojourn/Policy/`, `Sojourn/Secrets/`, persisted
schemas, Service actor public APIs, or external dependencies.

The pre-existing local `AGENTS.md` modification remains excluded from this
stage per the explicit plan.

## Final Diff Under Review

- Bumped `CURRENT_PROJECT_VERSION` from 33 to 34 in `project.yml` and
  regenerated `Sojourn.xcodeproj`.
- Updated `CHANGELOG.md` with a Stage 6 release-hardening entry.
- Removed Sojourn's app-owned Sparkle delta retry path after verifying
  Sparkle 2.9.1 owns delta-to-regular fallback and `4002` is
  `SUMissingUpdateError`.
- Updated Sparkle terminal failure copy to point users at GitHub Releases
  when retry keeps failing.
- Hardened `notarize.yml` by uploading the required versioned Sparkle DMG,
  making required Sparkle asset uploads fail on unmatched files, keeping delta
  uploads optional, and verifying generated appcast enclosure URLs before cask
  publishing.
- Corrected ADR-0025, `appcast.xml`, and `docs/process/release.md` to match
  current Sparkle and release-pipeline behavior.
- Updated install-source persistence tests to v0.4.0 fixtures.

## Council Votes

### Architect

Decision: Approve with conditions.

Conditions:
- Replace stale Apple app-specific-password notarization guidance with the
  App Store Connect API-key flow used by `scripts/notarize.sh`.
- Correct cache wording to describe current-tag save plus prefix restore.
- Add a `lessons.md` entry for the corrected Sparkle fallback/error-code
  assumption.

Resolutions:
- Release docs now describe `APPSTORE_API_KEY_ID`,
  `APPSTORE_API_ISSUER_ID`, and `APPSTORE_API_KEY_P8`, including the
  matching `notarytool log` command shape.
- ADR-0025 and workflow comments now describe current-tag save plus prefix
  restore.
- The ignored local agent memory file `lessons.md` records that Sparkle 2.9.1
  owns delta fallback and `4002` is `SUMissingUpdateError`.

### Security

Decision: Approve with conditions.

Conditions:
- Replace inline `TAP_TOKEN=...` release-doc examples with non-inline secret
  loading.

Resolutions:
- The Homebrew dry-run docs now load the tap token via `op read`, export it
  separately, run the dry run, and unset the variable.
- A low-risk pre-existing cask `on_upgrade: :quit` gap was noted but not
  changed in this stage.

### Devil's Advocate

Decision: Approve with conditions.

Conditions:
- Add a workflow guard that verifies the generated appcast has an EdDSA
  signature, verifies the versioned DMG asset resolves, and checks every
  generated enclosure URL.
- Either backfill the live v0.3.0 versioned DMG asset or explicitly record
  that v0.3.0 Sparkle appcast evidence is broken until v0.4.0 ships.
- Add the Sparkle lesson and rerun pre-commit gates.

Resolutions:
- `notarize.yml` now verifies `sparkle:edSignature=`, HEAD-checks the
  versioned DMG, parses generated enclosure URLs, bounds them to 11, and
  HEAD-checks each before cask publishing.
- The release runbook records that the live v0.3.0 appcast references
  `Sojourn-v0.3.0.dmg` while the release only contains `Sojourn.dmg`, so
  v0.3.0 Sparkle update evidence is broken until a fixed v0.4.0-or-later tag
  workflow publishes.
- The ignored local agent memory file `lessons.md` was updated and pre-commit
  gates were rerun.

### Perf Skeptic

Decision: Approve with conditions.

Conditions:
- Split required Sparkle asset upload from optional delta archive upload and
  set `fail_on_unmatched_files: true` where required.
- Add bounded post-upload appcast URL verification.

Resolutions:
- Required Sparkle assets (`appcast.xml` and
  `prior-dmgs/Sojourn-${{ github.ref_name }}.dmg`) upload in a required step
  with unmatched files treated as fatal.
- Delta archive upload runs only when `prior-dmgs/*.delta` exists.
- Appcast URL verification is bounded by a five-minute step timeout, 10-second
  HEAD requests, and at most 11 generated enclosure URLs.

### UX Critic

Decision: Approve with conditions.

Conditions:
- Add durable recovery copy for terminal Sparkle update failures.
- Update release workflow watch bullets to include Sparkle appcast generation,
  required versioned DMG upload, optional deltas, and enclosure URL checks.
- Replace literal tabs in the release runbook paragraph.

Resolutions:
- Sparkle terminal update failures now say to retry and install the latest DMG
  from GitHub Releases if failure persists.
- The runbook watch list now includes appcast generation, versioned Sparkle
  asset upload, optional delta upload, and generated enclosure URL checks.
- The tab-indented release paragraph was normalized to spaces.

## Verification

- Clean detached worktree verification, applying only the Stage 6 diff and
  excluding `AGENTS.md`, passed with `bash scripts/verify-agent-tooling.sh`.
- `swift-format lint --configuration .swift-format --strict
  Sojourn/Services/SparkleService.swift` passed.
- `xmllint --noout appcast.xml` passed.
- `actionlint .github/workflows/*.yml` passed.
- `zizmor .github/` passed.
- `git diff --check -- . ':!AGENTS.md'` passed.
- `swift build` passed.
- `swift test` passed: 195 tests in 45 suites.
- `xcodebuild test -project Sojourn.xcodeproj -scheme Sojourn -destination
  'platform=macOS,arch=arm64' -only-testing:SojournTests` passed: 195 tests
  in 45 suites.
- `make ci-local` passed, including actionlint, gitleaks, pinact, zizmor, and
  expiry validation. Broad historical SwiftLint/SwiftFormat warnings remain
  advisory under the Makefile.
- Release-script checks passed: `plutil -lint` on app/helper plists,
  `bash -n` on release scripts, live latest appcast XML parse, and
  `HOMEBREW_NO_AUTO_UPDATE=1 brew style ./Casks/sojourn.rb`.
- `make xcodebuild` remains blocked locally by the expected real Apple
  Development signing precondition (`DEVELOPMENT_TEAM` and
  `CODE_SIGN_IDENTITY`), so the unit-test-only Xcode command is the local
  fallback evidence.

## Verdict

Proceed with the Stage 6 release-hardening commit after rerunning final
gitleaks on the exact staged candidate. The only remaining local file outside
the commit candidate is the pre-existing `AGENTS.md` modification.
