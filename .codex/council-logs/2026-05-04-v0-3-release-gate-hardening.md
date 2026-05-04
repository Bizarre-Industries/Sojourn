# Council deliberation - v0.3 release gate hardening

Date: 2026-05-04

## Trigger

This change touches `.github/workflows/notarize.yml`, so the full council gate
is required before commit.

## Proposal

Harden the v0.3 release gates without tagging `v0.3.0` yet:

- restore SwiftPM build/test coverage with a package-only Sparkle fallback and
  explicit package resources;
- remove unsafe workflow interpolation and unpinned Homebrew action usage;
- keep Sparkle signing keys scoped to the appcast step and avoid secret
  tempfile persistence;
- bump build metadata to build 28 and regenerate `Sojourn.xcodeproj`;
- update stale release docs, ADRs, changelog, lessons, and UI smoke tests;
- preserve the release block on full signed UI tests, release appcast signing,
  corrupt-delta smoke testing, Gatekeeper assessment, and clean Tahoe release
  verification.

## Member Decisions

Architect: approve with conditions. Conditions were to align ADR-0020 with the
actual appcast host, remove stale changelog wording, and source lessons entries.
Those edits are included in this diff.

Security: approve with conditions. Workflow secret exposure was reduced by
moving the Sparkle EdDSA key into a dedicated `export-env: false` step, piping
it to `generate_appcast --ed-key-file -`, adding tag/repository validation, and
using private tempfiles for notarization credentials. Remaining conditions are
tag-time checks: prove the Xcode-resolved `generate_appcast` is the only tool
used, prove produced appcasts contain signed `sparkle:edSignature` entries,
run a corrupt-delta smoke check, and verify the notarized DMG/app on clean
Tahoe before release.

Devil advocate: approve with conditions. The main condition was to avoid
turning the Sparkle key into a job-wide environment variable; this is now
scoped to the appcast step. Remaining concerns are release-time evidence only:
signed full UI execution, v0.3.0-to-v0.3.1 delta behavior, corrupt-delta
failure behavior, and Gatekeeper verification.

Perf skeptic: approve. No additional performance concerns were raised for the
release-gate hardening patch.

UX critic: approve with conditions. The diagnostic Sparkle fallback comment
and Onboard template replacement copy were clarified so the no-op package
build does not read as a user-facing update mechanism and the Trash behavior
is explicit.

## Decision

Proceed with a release-gate hardening commit. Do not tag `v0.3.0`, push a
release tag, publish release artifacts, or create `docs/process/plans/v0.4-plan.md`
until the remaining release checks pass.

## Verification State

Passing in this workspace:

- `make ci-local`
- `swift build`
- `swift test`
- signed `xcodebuild build-for-testing`
- `git diff --check`

Blocked in this workspace:

- full signed `xcodebuild test` execution. Unsigned/ad-hoc loader failures and
  local signed hangs are not release evidence.

Remaining before tag:

- full signed UI test run;
- Sparkle public key replacement before release build;
- generated release appcast signature verification;
- corrupt-delta Tahoe smoke test;
- `spctl --assess --verbose=4` on clean Tahoe;
- `build.yml`, `codeql.yml`, and `notarize.yml` workflow verification after
  the actual `v0.3.0` tag.
