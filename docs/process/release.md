# Release runbook

Release authority: the Sojourn maintainer only. See
[MAINTAINERS.md](../MAINTAINERS.md).

## One-time setup (per maintainer workstation)

1. Apple Developer account + Developer ID Application certificate.
   Export as `.p12`, note the password.
2. Create an App Store Connect API key with Developer ID notarization
   access. Store the key ID, issuer ID, and private key payload for
   `notarytool`.
3. Register a GitHub OAuth App named "Sojourn". Paste the resulting
   `client_id` into
   [`Sojourn/Services/GitHubDeviceAuth.swift`](../Sojourn/Services/GitHubDeviceAuth.swift)
   (placeholder `SOJOURN_OAUTH_CLIENT_ID_PLACEHOLDER`).
4. Create `Bizarre-Industries/homebrew-sojourn` tap repo.
5. Create a fine-grained PAT with `contents:write` on the tap repo —
   paste as `HOMEBREW_TAP_TOKEN` in the release environment secrets.
6. Add GitHub repository secrets for the release environment, or map
   them from the 1Password `Load 1Password secrets` step in
   `notarize.yml`:
   - `DEVELOPER_ID_P12_BASE64` (base64 of the .p12)
   - `DEVELOPER_ID_P12_PASSWORD`
   - `DEVELOPER_ID_IDENTITY` (full cert common name)
   - `DEVELOPMENT_TEAM` (10-character Team ID)
   - `KEYCHAIN_PASSWORD` (arbitrary; gates the temp build keychain)
   - `APPSTORE_API_KEY_ID`
   - `APPSTORE_API_ISSUER_ID`
   - `APPSTORE_API_KEY_P8`
   - `SPARKLE_EDDSA_PRIVATE_KEY`
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
make ci-local       # release gate: actionlint, gitleaks, pins, zizmor, expiry, advisory Swift lint/format
make test           # swift test
make xcodebuild     # full Xcode test (mirrors build.yml's xcodebuild job)
make act-ci         # run ci.yml's ubuntu jobs in Docker via nektos/act
```

`act` cannot virtualize macOS runners — `make test` and `make xcodebuild`
are the local equivalents of the macOS jobs in `build.yml`.

## Per-release

1. Bump `MARKETING_VERSION` in `project.yml`. `Sojourn/Info.plist`
   reads `CFBundleShortVersionString` from that build setting.
2. Regenerate Xcode project: `make generate` (runs
   `scripts/regenerate-project.sh`).
3. Local pre-flight: `make ci-local && make test && make xcodebuild`.
   `make xcodebuild` includes `SojournUITests`, so it requires a real
   `DEVELOPMENT_TEAM` in `Sojourn/Config/Local.xcconfig` or passed as
   `DEVELOPMENT_TEAM=<Team ID>`, plus an explicit
   `CODE_SIGN_IDENTITY="Apple Development"`. An unsigned or ad-hoc
   local UI-test loader failure is not release evidence; use the
   `-only-testing:SojournTests` command only as a unit-test fallback
   while configuring signing. If the runner fails with `Timed out while
   enabling automation mode`, run
   `sudo xcrun automationmodetool enable-automationmode-without-authentication`,
   confirm Xcode/Xcode Helper are allowed in System Settings → Privacy &
   Security → Accessibility if prompted, then rerun `make xcodebuild`
   before counting the full UI-test gate as passed.
4. Sparkle pre-flight:
   ```sh
   curl -fsSLI https://github.com/Bizarre-Industries/Sojourn/releases/latest/download/appcast.xml
   curl -fsSL https://github.com/Bizarre-Industries/Sojourn/releases/latest/download/appcast.xml \
     | grep -E 'sparkle:(shortVersionString|version)|sparkle:edSignature'
   ```
   Before tagging, the URL should resolve to the most recent shipped
   release. After the tag workflow publishes the new release, repeat the
   check and verify the appcast advertises the new version and an EdDSA
   signature. Every `<enclosure url="...">` in the generated appcast
   must resolve; `notarize.yml` uploads a versioned full-DMG asset for
   Sparkle and the unversioned `Sojourn.dmg` asset for the cask path,
   then checks all generated enclosure URLs before cask publishing.
   As of 2026-05-05, the live v0.3.0 appcast references
   `Sojourn-v0.3.0.dmg`, but the release only contains `Sojourn.dmg`;
   treat v0.3.0 Sparkle update evidence as broken until a tag workflow
   with the versioned asset upload publishes v0.4.0 or later.
5. Cask pre-flight:
   ```sh
   HOMEBREW_NO_AUTO_UPDATE=1 brew style ./Casks/sojourn.rb
   ```
   Homebrew 5 disables path-based `brew audit` / `brew livecheck` for
   arbitrary local cask files. The tag workflow still performs local
   style checking, then `scripts/publish-homebrew-cask.sh` copies the
   bumped tap-side cask into the tapped Homebrew repository and runs
   name-based `brew audit --cask --online sojourn`.
6. Tag: `git tag -s vX.Y.Z -m "release vX.Y.Z"`.
7. Push tag: `git push origin vX.Y.Z`.
8. Watch GitHub Actions → `notarize.yml` workflow:
   - imports Developer ID keychain
   - downloads + verifies bundled binaries (gitleaks, age)
   - re-signs bundled binaries
   - `xcodebuild -configuration Release`
   - creates DMG via `scripts/make-dmg.sh`
   - notarizes + staples via `scripts/notarize.sh`
   - runs `spctl --assess` on `.app` AND `.dmg` **before** upload
   - generates `appcast.xml` with Sparkle full-DMG and delta entries
   - uploads `appcast.xml` and the required versioned Sparkle DMG
   - uploads optional Sparkle delta archives when prior DMGs exist
   - uploads `Sojourn.dmg` to GitHub Release
   - verifies every generated appcast enclosure URL resolves
   - invokes `scripts/publish-homebrew-cask.sh` to bump the tap
9. Download the DMG on a clean Tahoe VM and verify Gatekeeper
   accepts it: `spctl --assess --verbose=4 Sojourn.dmg`.

## Post-release

- Bump `MARKETING_VERSION` past the release to mark
  development-toward-next.
- Update `docs/reference/third-party.md` if dep versions changed.
- Update `docs/reference/package-managers/index.md` if manager coverage changed.

### Replan-on-ship hook

Opening an agent session in this repo after a `v*` tag is pushed fires
the project replan hook. Claude Code uses `.claude/hooks/replan-on-tag.sh`
and Codex uses `.codex/hooks/replan-on-tag.sh`. Each hook compares
`git tag -l 'v*'` against its per-clone marker
`.claude/.last-shipped-tag` or `.codex/.last-shipped-tag` (gitignored).
If a new tag is found, the next session writes the next active plan at
`docs/process/plans/v0.X-plan.md`.

After the new plan is written and approved, advance the marker with
`bash .claude/hooks/mark-replanned.sh <tag>` for Claude Code or
`bash .codex/hooks/mark-replanned.sh <tag>` for Codex so subsequent
sessions start clean. The marker is **per-clone, never committed**.

Manual override: edit the matching `.last-shipped-tag` directly (or
`rm` it to re-trigger), or write a tag string the hook should treat as
"already replanned."

## Troubleshooting

- **Notarize stalls:** inspect logs with
  `xcrun notarytool log <submissionID> --key <api-key.p8> --key-id <key-id> --issuer <issuer-id>`.
- **Gatekeeper rejects:** verify hardened runtime flag + timestamp in
  `scripts/sign.sh`; rerun `xcodebuild` with
  `OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"`.
- **Homebrew cask publish fails:** check `HOMEBREW_TAP_TOKEN` /
  `TAP_TOKEN` has write permission on `homebrew-sojourn/Casks/`; load
  it outside shell history, then run the dry run against the downloaded,
  notarized, stapled DMG:
  ```sh
  export TAP_TOKEN="$(op read op://Bizarre-Industries/sojourn-homebrew-tap-token/credential)"
  GITHUB_REF_NAME=vX.Y.Z scripts/publish-homebrew-cask.sh --dry-run ./Sojourn.dmg
  unset TAP_TOKEN
  ```
  The dry run performs clone, edit, verification, style, audit, and
  commit, but skips the final push.
