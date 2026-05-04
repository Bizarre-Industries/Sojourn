# Council deliberation - Sparkle public key and install source

Date: 2026-05-04

## Trigger

This change updates the Sparkle public key in `Sojourn/Info.plist` and release
update behavior. Treat it as release signing/update configuration, so the full
council gate is required before commit.

## Proposal

Close the remaining v0.3 Sparkle release blockers without tagging `v0.3.0`:

- replace the placeholder `SUPublicEDKey` with the checked 1Password public
  Sparkle key;
- persist first-launch install-source classification in `SettingsStore`;
- suppress Sparkle update checks for exact-version Homebrew cask installs;
- fail open to Sparkle for direct DMG and unknown installs;
- expose a General Settings override for install source;
- surface localized Sparkle status in the menu bar UI;
- keep v0.3 tagging blocked on real release artifact checks.

## Member Decisions

Architect: approve with conditions. Conditions were to reconcile ADR-0020 with
the actual persisted schema, avoid stale Caskroom misclassification, and provide
an override path. The diff now documents `SettingsStore.installSource`, requires
an exact current-version cask receipt, and adds a General Settings selector.

Security: approve with conditions. Conditions were to tighten stale cask
detection, keep public-key equality verification as release evidence, and avoid
staging unrelated ignored config. The detector now ignores nonmatching Caskroom
receipts. The public key was compared against the 1Password public field without
printing it and decoded to the expected 32-byte EdDSA key length. Unrelated
`.codex/` config and `AGENTS.md` remain unstaged.

Devil advocate: approve with conditions. Conditions were to add the install
source override before commit and keep tag-time appcast/Tahoe/Gatekeeper smoke
checks as blockers. The override is implemented; the tag remains blocked.

Perf skeptic: approve with conditions. Condition was to avoid constructing
Sparkle's updater controller on startup for Homebrew cask users. The controller
is now constructed lazily only when Sparkle is eligible or manually invoked.

UX critic: approve with conditions. Conditions were to keep the menu item label
stable, provide actionable Homebrew copy, avoid clipped status text, localize
user-visible strings, clear stale status, group accessibility, and expose the
install-source override. These conditions are included in the patch.

## Decision

Proceed with a v0.3 release-gate commit. Do not create or push the `v0.3.0` tag
until release artifacts prove the shipped appcast signatures, Sparkle fallback
behavior, cask/DMG install behavior, and Gatekeeper assessment on clean Tahoe.

## Verification State

Passing in this workspace:

- `swift build`
- `swift test` (152 tests, 41 suites)
- `make ci-local`
- `make xcodebuild CODE_SIGN_IDENTITY='Apple Development'` (152 unit tests and
  2 UI tests)
- non-printing `SUPublicEDKey` equality check against the 1Password public
  field, plus 32-byte decoded-key check

Advisory-only:

- SwiftLint still reports the existing strict backlog, now 130 serious findings
  and none added by `InstallSource`.
- `swift-format` still cannot read the existing `.swift-format` config under
  the current local tool; `make ci-local` treats this as advisory.

Remaining before tag:

- generate release appcast entries and verify `sparkle:edSignature` against the
  shipped public key;
- perform clean Tahoe direct-DMG and fresh Homebrew cask install smoke checks;
- perform Sparkle delta and corrupt-delta fallback smoke checks;
- verify the produced DMG/app with `spctl --assess --verbose=4` on clean Tahoe;
- push the tag only after the release artifact checks are complete, then watch
  `build.yml`, `codeql.yml`, and `notarize.yml`.
