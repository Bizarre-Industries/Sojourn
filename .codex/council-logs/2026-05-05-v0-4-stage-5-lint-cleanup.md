# Council Log: v0.4 Stage 5 Lint Cleanup

Date: 2026-05-05

## Trigger

Council fired because the Stage 5 commit candidate deletes more than 100 lines
in one commit while formatting and lint-cleaning the Stage 4 touched UI files.
No change touches `Sojourn/Policy/`, `Sojourn/Secrets/`, signing
configuration, `notarize.yml`, persisted schemas, Service actor public APIs, or
external dependencies.

The pre-existing local `AGENTS.md` modification remains excluded from this
stage per the explicit plan.

## Final Diff Under Review

- Bumped `CURRENT_PROJECT_VERSION` from 32 to 33 in `project.yml` and
  regenerated `Sojourn.xcodeproj`.
- Updated `CHANGELOG.md` with a Stage 5 lint-cleanup entry.
- Fixed `.swift-format` compatibility with the installed formatter and disabled
  formatter rules that conflict with strict SwiftLint on touched files.
- Applied targeted Swift formatting to the Stage 4 touched UI surfaces.
- Extracted package manager summary catalog data into
  `PackagesPaneModels.swift`, preserving the Stage 4 visible manager order.
- Reduced strict SwiftLint violations in `PackagesPane`, `SettingsScene`,
  `SyncPane`, and the UI smoke test helper data.

## Council Votes

### Architect

Decision: Approve with conditions.

Conditions:
- Exclude the transient `AGENTS.md` hunk from the commit.
- Preserve package manager ordering, or test and document the intended change.

Resolutions:
- `AGENTS.md` remains unstaged and outside the Stage 5 patch.
- Package manager ordering was restored to the Stage 4 sequence:
  `mas`, `brew`, `cargo`, `cask`, `uv`, `npm`, `go`, `vscode`, `krew`,
  `flatpak`, `tap`.

### Security

Decision: Approve with conditions.

Conditions:
- Do not commit the local `AGENTS.md` modification.
- Rerun agent-tooling verification against the actual commit candidate.
- Keep the gitleaks gate.

Resolutions:
- `AGENTS.md` remains excluded.
- The Stage 5 diff was applied to a clean detached worktree without
  `AGENTS.md`, and `bash scripts/verify-agent-tooling.sh` passed.
- `gitleaks dir --config=.gitleaks.toml --redact --no-banner` passed.

### Devil's Advocate

Decision: Approve with conditions.

Conditions:
- Do not let `AGENTS.md` ride along with the lint commit.
- Verify the extraction did not smuggle a user-visible package ordering change.

Resolutions:
- `AGENTS.md` remains unstaged.
- Package summaries now preserve the prior manager order while moving catalog
  data out of `PackagesPane`.

### UX Critic

Decision: Approve with conditions.

Conditions:
- Restore package manager summary order after the model extraction.

Resolutions:
- The visible manager order was restored. Static Settings links now avoid force
  unwraps; if URL construction ever fails, only the affected optional link is
  hidden.

### Perf Skeptic

Decision: Approve.

Notes:
- The package summary extraction moves constant catalog data out of the view and
  does not introduce new runtime work beyond small value construction.

## Verification

- `swift-format format -i --configuration .swift-format --parallel` passed on
  the touched UI set.
- `git diff --check` passed.
- `swiftlint lint --config .swiftlint.yml --strict --reporter xcode --no-cache`
  passed on the touched UI set with 0 violations.
- `swift-format lint --configuration .swift-format --parallel --strict` passed
  on the touched UI set.
- `swift build` passed.
- `swift test` passed: 195 tests in 45 suites.
- `xcodebuild build-for-testing -project Sojourn.xcodeproj -scheme Sojourn -destination 'platform=macOS,arch=arm64'` passed.
- `xcodebuild test -project Sojourn.xcodeproj -scheme Sojourn -destination 'platform=macOS,arch=arm64' -only-testing:SojournTests` passed:
  195 tests in 45 suites.
- `gitleaks dir --config=.gitleaks.toml --redact --no-banner` passed.
- Commit-candidate verification in a clean detached worktree, excluding
  `AGENTS.md`, passed with `bash scripts/verify-agent-tooling.sh`.

## Verdict

Proceed with the Stage 5 lint-cleanup commit. The only remaining local file
outside the commit candidate is the pre-existing `AGENTS.md` modification.
