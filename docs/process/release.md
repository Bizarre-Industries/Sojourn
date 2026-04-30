# Release runbook

Release authority: the Sojourn maintainer only. See
[MAINTAINERS.md](../MAINTAINERS.md).

## One-time setup (per maintainer workstation)

1. Apple Developer account + Developer ID Application certificate.
   Export as `.p12`, note the password.
2. Generate an Apple app-specific password from
   <https://appleid.apple.com> (for `notarytool`).
3. Register a GitHub OAuth App named "Sojourn". Paste the resulting
   `client_id` into
   [`Sojourn/Services/GitHubDeviceAuth.swift`](../Sojourn/Services/GitHubDeviceAuth.swift)
   (placeholder `SOJOURN_OAUTH_CLIENT_ID_PLACEHOLDER`).
4. Create `Bizarre-Industries/homebrew-sojourn` tap repo.
5. Create a fine-grained PAT with `contents:write` on the tap repo —
   paste as `HOMEBREW_TAP_TOKEN` in the release environment secrets.
6. Add GitHub repository secrets for the release environment:
   - `DEVELOPER_ID_P12_BASE64` (base64 of the .p12)
   - `DEVELOPER_ID_P12_PASSWORD`
   - `DEVELOPER_ID_IDENTITY` (full cert common name)
   - `DEVELOPMENT_TEAM` (10-character Team ID)
   - `KEYCHAIN_PASSWORD` (arbitrary; gates the temp build keychain)
   - `APPLE_ID` (Apple ID email)
   - `APPLE_APP_SPECIFIC_PASSWORD`
   - `HOMEBREW_TAP_TOKEN`
7. Set `DEVELOPMENT_TEAM` in a local `Sojourn/Config/Local.xcconfig`
   (gitignored) for Xcode signing.

## Workflow split

Heavy build + Xcode test + notarize **only run on `v*` tag push**. Every
normal commit runs only quality + security checks.

| Workflow             | Trigger                            | Runs                                                                                                              |
| -------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `ci.yml`             | push/PR to `main`                  | gitleaks scan, SwiftLint (advisory), swift-format (advisory)                                                      |
| `codeql.yml`         | push tag `v*` + weekly cron + `workflow_dispatch` | CodeQL static analysis (requires `swift build`, kept off the per-commit path)                          |
| `build.yml`          | push tag `v*` + `workflow_dispatch`| `swift test`, `xcodebuild test` (UITests skipped — Team-ID gated)                                                 |
| `notarize.yml`       | push tag `v*`                      | sign + notarize + DMG + Homebrew cask publish                                                                     |

A normal commit never spends macOS runner minutes on the heavy test path.
Tag push triggers `build.yml` first; `notarize.yml` runs in parallel
because it doesn't `needs:` build (failures are caught in the concurrent
`xcodebuild` step inside notarize itself).

## Local verification (run BEFORE every commit)

```sh
make ci-local       # mirrors ci.yml: actionlint + gitleaks + swiftlint + swift-format
make test           # swift test
make xcodebuild     # full Xcode test (mirrors build.yml's xcodebuild job)
make act-ci         # run ci.yml's ubuntu jobs in Docker via nektos/act
```

`act` cannot virtualize macOS runners — `make test` and `make xcodebuild`
are the local equivalents of the macOS jobs in `build.yml`.

## Per-release

1. Bump `CFBundleShortVersionString` in `Sojourn/Info.plist` and
   `MARKETING_VERSION` in `project.yml`.
2. Regenerate Xcode project: `make generate` (runs
   `scripts/regenerate-project.sh`).
3. Local pre-flight: `make ci-local && make test && make xcodebuild`.
4. Tag: `git tag -s vX.Y.Z -m "release vX.Y.Z"`.
5. Push tag: `git push origin vX.Y.Z`.
6. Watch GitHub Actions → `notarize.yml` workflow:
   - imports Developer ID keychain
   - downloads + verifies bundled binaries (gitleaks, age)
   - re-signs bundled binaries
   - `xcodebuild -configuration Release`
   - creates DMG via `scripts/make-dmg.sh`
   - notarizes + staples via `scripts/notarize.sh`
   - runs `spctl --assess` on `.app` AND `.dmg` **before** upload
   - uploads `Sojourn.dmg` to GitHub Release
   - invokes `scripts/publish-homebrew-cask.sh` to bump the tap
7. Download the DMG on a clean Sequoia/Tahoe VM and verify Gatekeeper
   accepts it: `spctl --assess --verbose=4 Sojourn.dmg`.

## Post-release

- Bump `MARKETING_VERSION` past the release to mark
  development-toward-next.
- Update `docs/reference/third-party.md` if dep versions changed.
- Update `docs/SUPPORTED_MANAGERS.md` if manager coverage changed.

### Replan-on-ship hook

Opening a Claude Code session in this repo after a `v*` tag is pushed
fires `.claude/hooks/replan-on-ship.sh` (wired via `.claude/settings.json`
on `SessionStart` + `Stop`). The hook compares `git tag -l 'v*'` against
the per-clone marker `.claude/.last-shipped-tag` (gitignored). If a new
tag is found it injects a system-context message instructing Claude to
reanalyze the repo, docs, and `docs/process/implementation-plan.md` and
write a new plan at `~/.claude/plans/sojourn-post-<tag>.md` toward the
next version per the phase ladder.

After the new plan is written and approved, Claude advances the marker
with `bash .claude/hooks/mark-replanned.sh <tag>` so subsequent sessions
start clean. The marker is **per-clone, never committed** — each
maintainer workstation re-prompts independently.

Manual override: edit `.claude/.last-shipped-tag` directly (or `rm` it to
re-trigger), or write a tag string the hook should treat as "already
replanned."

## Troubleshooting

- **Notarize stalls:** inspect logs with
  `xcrun notarytool log <submissionID> --apple-id ... --team-id ... --password ...`.
- **Gatekeeper rejects:** verify hardened runtime flag + timestamp in
  `scripts/sign.sh`; rerun `xcodebuild` with
  `OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"`.
- **Homebrew cask publish fails:** check HOMEBREW_TAP_TOKEN has write
  permission on `homebrew-sojourn/Casks/`; run
  `scripts/publish-homebrew-cask.sh vX.Y.Z` locally with
  `SOJOURN_DMG_PATH=./Sojourn.dmg` pointing to the downloaded DMG.
