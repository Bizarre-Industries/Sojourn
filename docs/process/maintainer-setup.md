# Maintainer setup

End-to-end checklist for getting Sojourn from "code in the repo" to
"signed, notarized, distributable DMG via tag-triggered CI" — plus the
Sigstore prep for v1.x plugin signing per
[decisions/0015-keyless-cosign-plugin-trust.md](../decisions/0015-keyless-cosign-plugin-trust.md)
and an in-repo expiry-tracking system that opens GitHub issues when
secrets need rotating.

Order matters: each phase builds on artefacts from the prior one.

---

## Phase 1 — Apple Team ID + Local.xcconfig

Three minutes. Unblocks local Xcode builds.

### 1.1 Get your Team ID

```sh
defaults read MobileMeAccounts Accounts | grep -A1 'AccountID' | head
```

Or visit <https://developer.apple.com/account> → membership details →
"Team ID" (10-char alphanumeric, e.g. `ABCD123456`).

### 1.2 Create `Sojourn/Config/Local.xcconfig`

Gitignored. Both `Debug.xcconfig` and `Release.xcconfig` already do
`#include? "Local.xcconfig"` so it just slots in.

```sh
cat > Sojourn/Config/Local.xcconfig <<'EOF'
DEVELOPMENT_TEAM = ABCD123456
EOF
```

Verify:

```sh
make generate
xcodebuild -project Sojourn.xcodeproj -scheme Sojourn \
  -configuration Debug -showBuildSettings | grep DEVELOPMENT_TEAM
```

---

## Phase 2 — Developer ID Application certificate

Ten minutes. Required for code-signing the app + bundled binaries
outside Mac App Store.

### 2.1 Create the cert via Xcode

1. Xcode → **Settings → Accounts**.
2. Sign in with the Apple ID tied to your developer account.
3. Select your team → **Manage Certificates…**.
4. `+` (bottom-left) → **Developer ID Application**.
5. Xcode generates CSR, submits to Apple, downloads, installs in your
   login Keychain.

### 2.2 Verify

```sh
security find-identity -v -p codesigning
```

Look for:

```
1) ABC123… "Developer ID Application: Your Name (ABCD123456)"
```

The full quoted string is `DEVELOPER_ID_IDENTITY`.

### 2.3 Quick sign test

```sh
echo "test" > /tmp/sign-test.txt
codesign --sign "Developer ID Application: Your Name (ABCD123456)" \
  --options runtime --timestamp /tmp/sign-test.txt
codesign --verify --verbose=2 /tmp/sign-test.txt
```

If verify reports `valid on disk` and `satisfies its Designated
Requirement`, both your cert and Apple's timestamp service work.

---

## Phase 3 — Notarization credential

Five minutes. **Path B (App Store Connect API key)** — required for the
Phase 12 expiry-check workflow to query Apple directly. Doesn't break
on Apple ID 2FA / password rotation. No expiry on the key itself.

### 3.1 Generate API Key

1. <https://appstoreconnect.apple.com/access/integrations/api>.
2. **Generate API Key** → **Access**: "Developer" role minimum
   (sufficient for notarization + cert listing).
3. Note the **Issuer ID** at top of page (UUID).
4. Download the `.p8` file. **One-time download** — re-issue if lost.
5. Note the **Key ID** (10 chars).

Three values to keep:

- `APPSTORE_API_KEY_ID` (10 chars)
- `APPSTORE_API_ISSUER_ID` (UUID)
- `APPSTORE_API_KEY_P8` (full contents of the `.p8` file, including
  `-----BEGIN/END PRIVATE KEY-----` lines)

### 3.2 Validate locally

```sh
xcrun notarytool history \
  --key /path/to/AuthKey_XYZ9876543.p8 \
  --key-id "XYZ9876543" \
  --issuer "your-issuer-uuid"
```

Empty history is fine — call succeeding (no auth error) is what
matters.

### 3.3 Update `scripts/notarize.sh` for Path B

```sh
#!/usr/bin/env bash
set -euo pipefail

DMG="${1:?usage: notarize.sh <path/to/Sojourn.dmg>}"

: "${APPSTORE_API_KEY_ID:?required}"
: "${APPSTORE_API_ISSUER_ID:?required}"
: "${APPSTORE_API_KEY_P8:?required}"

KEY_FILE="$(mktemp -t sojourn-notary.XXXX).p8"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$APPSTORE_API_KEY_P8" > "$KEY_FILE"

echo "submitting $DMG to notary service..."
xcrun notarytool submit "$DMG" \
  --key "$KEY_FILE" \
  --key-id "$APPSTORE_API_KEY_ID" \
  --issuer "$APPSTORE_API_ISSUER_ID" \
  --wait --timeout 30m

echo "stapling ticket to $DMG..."
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "notarization complete."
```

Update `notarize.yml` → "Notarize DMG" step env:

```yaml
- name: Notarize DMG
  env:
    APPSTORE_API_KEY_ID: ${{ secrets.APPSTORE_API_KEY_ID }}
    APPSTORE_API_ISSUER_ID: ${{ secrets.APPSTORE_API_ISSUER_ID }}
    APPSTORE_API_KEY_P8: ${{ secrets.APPSTORE_API_KEY_P8 }}
  run: bash scripts/notarize.sh Sojourn.dmg
```

---

## Phase 4 — GitHub OAuth App for Device Flow

Five minutes. Powers Sojourn's optional Device Flow auth for git
remotes.

The app stores `client_id` only — Device Flow doesn't use a client
secret.

1. <https://github.com/settings/developers> → **OAuth Apps** → **New
   OAuth App**.
2. Fields:
   - Application name: `Sojourn`
   - Homepage URL: `https://github.com/Bizarre-Industries/Sojourn`
   - Authorization callback URL: `https://github.com/Bizarre-Industries/Sojourn`
     (unused by Device Flow, required by form)
   - **Enable Device Flow**: ✓
3. Register → copy **Client ID** (`Iv1.…` or `Ov23…`).
4. **Don't generate a client secret.**

Add to `Local.xcconfig`:

```sh
cat >> Sojourn/Config/Local.xcconfig <<'EOF'
SOJOURN_OAUTH_CLIENT_ID = Iv1.your-client-id-here
EOF
```

Inject into CI builds — append to `notarize.yml` after `actions/checkout`:

```yaml
- name: Inject Local.xcconfig
  env:
    OAUTH_CLIENT_ID: ${{ secrets.SOJOURN_OAUTH_CLIENT_ID }}
    DEVELOPMENT_TEAM: ${{ secrets.DEVELOPMENT_TEAM }}
  run: |
    cat > Sojourn/Config/Local.xcconfig <<EOF
    DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM
    SOJOURN_OAUTH_CLIENT_ID = $OAUTH_CLIENT_ID
    EOF
```

---

## Phase 5 — Homebrew tap repo

Five minutes.

### 5.1 Create

```sh
gh repo create Bizarre-Industries/homebrew-sojourn \
  --public \
  --description "Homebrew cask for Sojourn" \
  --add-readme
```

Naming is significant: GitHub-hosted Homebrew taps must be
`<user>/homebrew-<name>` so users install via
`brew tap bizarre-industries/sojourn`.

### 5.2 Generate fine-grained PAT

`HOMEBREW_TAP_TOKEN` needs write access to **only** the tap.

1. <https://github.com/settings/personal-access-tokens/new>.
2. Token name: `Sojourn release → homebrew-sojourn`.
3. Resource owner: `Bizarre-Industries`.
4. Repository access: Only select repositories → `homebrew-sojourn`.
5. Repository permissions:
   - Contents: Read and write
   - Metadata: Read (auto)
6. Expiration: 1 year. Phase 12 will track expiry automatically.
7. Generate → copy the `github_pat_…` token.

---

## Phase 6 — Convert cert to CI format

Ten minutes.

### 6.1 Export `.p12`

1. Keychain Access → "login" → **My Certificates**.
2. Find `Developer ID Application: Your Name (TEAM)` row that
   **expands to show a private key**. (No key = re-do Phase 2.)
3. Right-click → **Export**.
4. Format: **Personal Information Exchange (.p12)**.
5. Save to `~/Desktop/dev-id.p12`.
6. Set a strong password — `DEVELOPER_ID_P12_PASSWORD`. Save in
   1Password.

### 6.2 Base64-encode

```sh
base64 -i ~/Desktop/dev-id.p12 | pbcopy
```

This is `DEVELOPER_ID_P12_BASE64`.

### 6.3 Generate `KEYCHAIN_PASSWORD`

```sh
openssl rand -base64 32 | pbcopy
```

### 6.4 Verify

```sh
security create-keychain -p "test-password" /tmp/test.keychain
security import ~/Desktop/dev-id.p12 -P "<your-p12-password>" -A \
  -t cert -f pkcs12 -k /tmp/test.keychain
security find-identity -v /tmp/test.keychain
security delete-keychain /tmp/test.keychain
```

Should list one identity with your Developer ID.

### 6.5 Securely delete

After Phase 7 confirms the secret is set:

```sh
rm -P ~/Desktop/dev-id.p12
pbcopy < /dev/null
```

---

## Phase 7 — Set GitHub Actions secrets

```sh
gh secret set DEVELOPMENT_TEAM --body "ABCD123456"
gh secret set DEVELOPER_ID_IDENTITY --body "Developer ID Application: Your Name (ABCD123456)"
gh secret set DEVELOPER_ID_P12_PASSWORD --body "<your-p12-password>"
gh secret set KEYCHAIN_PASSWORD --body "<openssl rand output>"

gh secret set APPSTORE_API_KEY_ID --body "XYZ9876543"
gh secret set APPSTORE_API_ISSUER_ID --body "your-issuer-uuid"
gh secret set APPSTORE_API_KEY_P8 < ~/Downloads/AuthKey_XYZ9876543.p8

gh secret set SOJOURN_OAUTH_CLIENT_ID --body "Iv1.your-client-id"
gh secret set HOMEBREW_TAP_TOKEN --body "github_pat_xxxxxxxxxxxx"
gh secret set DEVELOPER_ID_P12_BASE64 --body "$(pbpaste)"
```

Verify (`gh secret list`):

```
APPSTORE_API_ISSUER_ID
APPSTORE_API_KEY_ID
APPSTORE_API_KEY_P8
DEVELOPER_ID_IDENTITY
DEVELOPER_ID_P12_BASE64
DEVELOPER_ID_P12_PASSWORD
DEVELOPMENT_TEAM
HOMEBREW_TAP_TOKEN
KEYCHAIN_PASSWORD
SOJOURN_OAUTH_CLIENT_ID
```

`GITHUB_TOKEN` is auto-provided.

---

## Phase 8 — First release dry-run

```sh
git tag v0.0.1-test
git push origin v0.0.1-test
gh run watch
```

Expected ~15–25 min. After success:

```sh
gh release delete v0.0.1-test --yes --cleanup-tag
```

---

## Phase 9 — v1.x prep: cosign in bundled binaries

ADR-0015 needs `cosign` available at runtime.

### 9.1 Update `scripts/download-bundled-bins.sh`

```sh
COSIGN_VERSION="3.0.3"  # or latest stable

case "$ARCH" in
  arm64)
    COSIGN_ASSET="cosign-darwin-arm64"
    COSIGN_SHA256="TBD"
    ;;
  x86_64)
    COSIGN_ASSET="cosign-darwin-amd64"
    COSIGN_SHA256="TBD"
    ;;
esac

echo "downloading cosign ${COSIGN_VERSION}..."
gh release download "v${COSIGN_VERSION}" \
  --repo sigstore/cosign \
  --pattern "${COSIGN_ASSET}" \
  --dir "$TMP"
verify_sha "$TMP/${COSIGN_ASSET}" "$COSIGN_SHA256"
mv "$TMP/${COSIGN_ASSET}" "$BIN_DIR/cosign"
chmod +x "$BIN_DIR/cosign"
```

To get the SHA256, after first download:

```sh
shasum -a 256 Sojourn/Resources/bin/cosign
```

### 9.2 Sign cosign with Developer ID

`scripts/sign.sh` — add to the for-loop:

```sh
for binary in "$BIN_DIR"/gitleaks "$BIN_DIR"/age "$BIN_DIR"/cosign; do
```

---

## Phase 10 — v1.x prep: `Bizarre-Industries/sojourn-plugins` mono-repo

Mono-repo under existing org. **Per-plugin caller workflows** for trust
isolation — each plugin's `cert_identity` is unique.

### 10.1 Create the repo

```sh
gh repo create Bizarre-Industries/sojourn-plugins \
  --public \
  --description "Reference plugins for Sojourn (mise, gh-extension, krew, …)" \
  --add-readme
```

### 10.2 Layout

```
sojourn-plugins/
├── README.md
├── plugins/
│   ├── mise/
│   │   ├── manifest.toml
│   │   ├── plugin                        # the executable
│   │   ├── plugin.cosign.bundle          # generated by CI
│   │   └── src/                          # source
│   ├── gh-extension/
│   │   ├── manifest.toml
│   │   └── …
│   └── krew/
│       └── …
└── .github/
    └── workflows/
        ├── _release.yml                  # reusable workflow (shared logic)
        ├── release-mise.yml              # caller; per-plugin cert_identity
        ├── release-gh-extension.yml
        └── release-krew.yml
```

**Why per-plugin caller workflows**: keyless cosign's `cert_identity`
is the URL of the workflow file that performed the OIDC token exchange.
With a single shared workflow + matrix, all plugins collapse to the
same `cert_identity`. A compromise of any plugin's signing path then
forges-anything across the org. Per-plugin caller workflows give each
plugin a unique URL → unique `cert_identity` → trust is isolated.

The `_release.yml` reusable workflow encapsulates the shared signing
logic. Each `release-<plugin>.yml` is a thin caller. Caller URL is what
gets encoded in the OIDC token's `job_workflow_ref`, **not** the
reusable's URL — which is the security property we want.

### 10.3 Tag scheme

Namespaced per plugin so versions are independent:

- `mise-v0.1.0`, `mise-v0.2.0`, …
- `gh-extension-v0.1.0`, …
- `krew-v0.1.0`, …

Each `release-<plugin>.yml` filters its own tag pattern.

### 10.4 Reusable workflow `_release.yml`

```yaml
# .github/workflows/_release.yml
name: _release (reusable)
on:
  workflow_call:
    inputs:
      plugin_dir:
        type: string
        required: true
      tag_name:
        type: string
        required: true

permissions:
  contents: write
  id-token: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Build plugin
        working-directory: plugins/${{ inputs.plugin_dir }}
        run: |
          # Plugin-specific build. Could be a Makefile target,
          # `go build`, `swift build`, `cargo build`, etc.
          # Output must be `./plugin` in the plugin dir.
          test -f plugin || { echo "build did not produce ./plugin"; exit 1; }

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign plugin (keyless)
        working-directory: plugins/${{ inputs.plugin_dir }}
        run: |
          cosign sign-blob --yes \
            --bundle plugin.cosign.bundle \
            plugin

      - name: Smoke verify
        working-directory: plugins/${{ inputs.plugin_dir }}
        env:
          CALLER_REF: ${{ github.workflow_ref }}
        run: |
          # CALLER_REF is the per-plugin caller workflow URL — exactly
          # what cert_identity in the manifest must match.
          cosign verify-blob \
            --bundle plugin.cosign.bundle \
            --certificate-identity "https://github.com/${CALLER_REF%%@*}@refs/tags/${{ inputs.tag_name }}" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            plugin

      - name: Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ inputs.tag_name }}
          files: |
            plugins/${{ inputs.plugin_dir }}/plugin
            plugins/${{ inputs.plugin_dir }}/plugin.cosign.bundle
            plugins/${{ inputs.plugin_dir }}/manifest.toml
```

### 10.5 Per-plugin caller `release-mise.yml`

```yaml
# .github/workflows/release-mise.yml
name: Release mise plugin
on:
  push:
    tags: ["mise-v*"]

permissions:
  contents: write
  id-token: write

jobs:
  release:
    uses: ./.github/workflows/_release.yml
    with:
      plugin_dir: mise
      tag_name: ${{ github.ref_name }}
```

Equivalent files for `release-gh-extension.yml` (`tags: ['gh-extension-v*']`),
`release-krew.yml`, etc. Each has a unique URL.

### 10.6 Per-plugin manifest `cert_identity`

For mise:

```toml
# plugins/mise/manifest.toml
[plugin]
name = "mise"
version = "0.1.0"

[capabilities]
installed = true
outdated = true
install = true
remove = true
upgrade = true

[defaults]
tier = "C"
cooldown_days = 7

[signature]
mode             = "keyless"
cert_identity    = "https://github.com/Bizarre-Industries/sojourn-plugins/.github/workflows/release-mise.yml@refs/tags/mise-v*"
cert_oidc_issuer = "https://token.actions.githubusercontent.com"
```

For gh-extension:

```toml
[signature]
mode             = "keyless"
cert_identity    = "https://github.com/Bizarre-Industries/sojourn-plugins/.github/workflows/release-gh-extension.yml@refs/tags/gh-extension-v*"
cert_oidc_issuer = "https://token.actions.githubusercontent.com"
```

Different workflow URL per plugin → trust isolation holds. **Decide
once before shipping the first plugin** — the cert_identity becomes
sticky once cached on user machines.

### 10.7 Trust list entries

Sojourn ships with the trust list pre-populated for first-party
plugins at `~/Library/Application Support/Sojourn/plugins/trust.toml`:

```toml
[[trusted]]
cert_identity_pattern = "https://github.com/Bizarre-Industries/sojourn-plugins/.github/workflows/release-*.yml@refs/tags/*"
cert_oidc_issuer      = "https://token.actions.githubusercontent.com"
note                  = "First-party plugins from Bizarre-Industries"
```

The glob covers all current and future first-party plugins because
they all live in this repo and follow `release-<name>.yml`. Third-party
plugins require explicit user-added entries.

### 10.8 Update ADR-0015 + plugin-protocol.md example URLs

Both currently reference `sojourn-plugins/mise` (separate-org example).
Replace with the mono-repo URLs above. The decision in those files is
unchanged — only the example URL strings.

---

## Phase 11 — Housekeeping

Concrete content for each item. Don't skip.

### 11.1 1Password vault entry

Single `Sojourn release infrastructure` Secure Note item — rotation
becomes one-place editing:

| Field                             | Value                                              |
| --------------------------------- | -------------------------------------------------- |
| Apple Team ID                     | `ABCD123456`                                       |
| Developer ID cert identity string | `Developer ID Application: Your Name (ABCD123456)` |
| Developer ID cert issued          | `2026-04-30`                                       |
| Developer ID cert expires         | `2031-04-30`                                       |
| .p12 password                     | `<your-p12-password>`                              |
| .p12 file                         | (attach the actual .p12)                           |
| Keychain build password           | `<openssl rand output>`                            |
| App Store Connect API Key ID      | `XYZ9876543`                                       |
| App Store Connect Issuer ID       | `<uuid>`                                           |
| App Store Connect .p8 file        | (attach)                                           |
| GitHub OAuth client ID            | `Iv1.…`                                            |
| Homebrew tap PAT issued           | `2026-04-30`                                       |
| Homebrew tap PAT expires          | `2027-04-30`                                       |
| Homebrew tap PAT                  | `github_pat_…`                                     |

Rotation flow becomes: edit vault item → run the matching
`gh secret set` commands → done.

### 11.2 RELEASE_CHECKLIST.md

Drop into repo root:

````markdown
# Release checklist

Before tagging:

1. [ ] `make ci-local` passes (gitleaks, lint, format).
2. [ ] `make test` passes.
3. [ ] `make xcodebuild` passes.
4. [ ] Update `gitleaks` and `age` versions in `scripts/download-bundled-bins.sh` to current upstream stable. Re-pin SHA256s.
5. [ ] Update `cosign` version (v1.x onwards). Re-pin SHA256.
6. [ ] CHANGELOG.md entry under new version heading.
7. [ ] README.md screenshots up to date if UI changed.
8. [ ] No `TBD` left in `download-bundled-bins.sh` checksums.
9. [ ] `gh secret list` matches Phase 7 required-list.
10. [ ] No open `rotation-needed*` issues from Phase 12.

Tag and ship:

```sh
VERSION="v0.1.0"
git tag "$VERSION"
git push origin "$VERSION"
gh run watch
```
````

Post-release:

11. [ ] DMG downloads from release page.
12. [ ] DMG opens; Gatekeeper accepts.
13. [ ] `brew tap bizarre-industries/sojourn && brew install --cask sojourn` works on a fresh Mac.
14. [ ] Sojourn launches; bootstrap completes; first push works.
15. [ ] CHANGELOG entry copied into the GitHub release notes.

````

Commit it.

### 11.3 Re-pin bundled binaries before first public release

```sh
gh release list --repo gitleaks/gitleaks --limit 1
gh release list --repo FiloSottile/age --limit 1
gh release list --repo sigstore/cosign --limit 1   # v1.x

# Update *_VERSION variables in scripts/download-bundled-bins.sh, then:
bash scripts/download-bundled-bins.sh
shasum -a 256 Sojourn/Resources/bin/{gitleaks,age,cosign}
# Paste each value into the matching *_SHA256 variable.
````

Then re-run the script with `STRICT_CHECKSUMS=1` env var — must pass.

### 11.4 Apple WWDR intermediate cert handling

GitHub macos-15 runners bundle Apple's intermediate CA. If notarize.yml
ever fails with `unable to build chain to self-signed root`:

```yaml
# Add before "Build Sojourn.app" in notarize.yml:
- name: Install Apple WWDR intermediate
  run: |
    curl -sO https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
    sudo security import AppleWWDRCAG3.cer \
      -k /Library/Keychains/System.keychain \
      -T /usr/bin/codesign
    rm AppleWWDRCAG3.cer
```

Don't add preemptively.

### 11.5 Branch protection on `main`

Enable once you start receiving PRs:

```sh
gh api -X PUT "repos/Bizarre-Industries/Sojourn/branches/main/protection" \
  -f required_status_checks.strict=true \
  -f required_status_checks.contexts[]='gitleaks' \
  -f required_status_checks.contexts[]='swift-test' \
  -f required_status_checks.contexts[]='actionlint' \
  -f enforce_admins=false \
  -f required_pull_request_reviews.required_approving_review_count=0 \
  -f restrictions=null
```

`enforce_admins=false` lets you push directly as maintainer for the
autonomous-commit pattern in [CLAUDE.md](../../CLAUDE.md). Flip to
`true` if you ever take on co-maintainers.

### 11.6 Runner version pinning

`notarize.yml` pins `runs-on: macos-15`. Already correct. When macos-16
ships and you want to bump:

1. PR that flips `macos-15` → `macos-16` in `notarize.yml`.
2. Tag `v0.0.X-test` on the PR branch.
3. If end-to-end succeeds, merge.

### 11.7 Diagnostic bundle hygiene

`diagnostics.bundle_includes_history_db = true` default + 365d `jobs`
retention means exported bundles can carry a year of operational
history. Useful for support.

Rule: never paste a bundle into a public issue without extracting it
locally first and grepping for `your-real-name`, hostnames, etc. The
redactor strips `/Users/<name>/` and `~/Library/` paths but won't catch
arbitrary identifying content from log lines.

### 11.8 Backup the .p12 outside the laptop

If your Mac dies and the only `.p12` copy was on it:

- 1Password has it (Phase 11.1) → re-base64 → re-set CI secret. 30
  minutes of recovery.

If 1Password also has problems and you need the cert without `.p12`
recovery:

- Re-issue from Apple. Old signed releases still verify; new releases
  need a new chain. ~24h round-trip with Apple's queue.

This is why .p12 → 1Password isn't optional.

### 11.9 Document the team-ID-and-cert-string outside the repo

A new Mac onboarding for Sojourn maintainership needs to know:

- Apple ID + Team ID (Phase 1)
- Developer ID cert identity string (Phase 2.2)
- App Store Connect API key+issuer (Phase 3)

All of these live in 11.1's vault entry. If you ever offboard a Mac (or
add a co-maintainer Mac), the vault item is the single thing they need
to import.

---

## Phase 12 — In-repo expiry tracking

Replaces external calendar reminders. A scheduled workflow reads a
tracked YAML config, fetches **live** expiry from APIs where possible,
and opens GitHub issues at threshold crossings. Issues land in your
existing task surface; survives Mac changes; auditable.

### 12.1 Why not a marketplace action

The marketplace SSL-cert-expiry actions assume live HTTPS endpoints to
TLS-handshake against. Code-signing certs, GitHub PATs, and Apple API
keys aren't reachable that way. Custom workflow is the answer.

### 12.2 Design

| Item                               | Query path                                    | Manual date needed? |
| ---------------------------------- | --------------------------------------------- | ------------------- |
| Developer ID Application cert      | App Store Connect API `/v1/certificates`      | No                  |
| Homebrew tap PAT                   | GitHub API `/user` (token introspection)      | No                  |
| App Store Connect API key          | n/a (no real expiry; tracks rotation cadence) | Manual              |
| Apple Developer Program membership | App Store Connect API                         | No                  |

For each, the workflow records `days_until_expiry` and opens/updates a
GitHub issue when:

- ≤ 60 days → open issue, label `rotation-needed`
- ≤ 30 days → escalate label to `rotation-needed-30d`
- ≤ 14 days → escalate to `rotation-needed-14d`
- ≤ 7 days → escalate to `rotation-needed-7d`
- ≤ 0 days → label `rotation-expired`, body updated red

Issue auto-closes when:

- Live API query returns a fresh expiry past all thresholds (no manual
  update needed), OR
- Manual `manual_expiry` date in YAML is updated past the threshold and
  committed

### 12.3 Files this phase delivers

Three files, all in this changeset:

| File                                 | Purpose                                                      |
| ------------------------------------ | ------------------------------------------------------------ |
| `.github/expiry-tracking.yml`        | Config: items to track, manual dates, thresholds             |
| `.github/workflows/expiry-check.yml` | Scheduled workflow that runs the check                       |
| `.github/scripts/check-expiry.py`    | Python script that queries APIs, opens/updates/closes issues |

See those files for full content. High-level walkthrough below.

### 12.4 Config: `.github/expiry-tracking.yml`

Schema validated by `check-expiry.py --validate`. Each `item` has:

- `id` — unique snake_case identifier (used in issue titles)
- `description` — human-readable
- `query` — `apple_cert | github_pat | manual`
- `apple_cert_type` — when `query=apple_cert`: `DEVELOPER_ID_APPLICATION`
- `manual_expiry` — when `query=manual`: ISO-8601 date the item expires
- `thresholds` — days at which to open/escalate (default `[60, 30, 14, 7, 0]`)
- `rotation_notes` — instructions shown in the issue body so you don't
  have to remember the rotation steps

### 12.5 First-run setup

After committing the workflow + config + script:

```sh
# Ensure labels exist (idempotent):
for label in rotation-needed rotation-needed-30d rotation-needed-14d \
             rotation-needed-7d rotation-expired rotation-system-failure; do
  gh label create "$label" --color FF6B6B --force 2>/dev/null || true
done

# Manually trigger the first run to verify everything works:
gh workflow run expiry-check.yml
gh run watch
```

### 12.6 Rotation flow

When you rotate something (say the Homebrew PAT):

1. Generate new PAT.
2. `gh secret set HOMEBREW_TAP_TOKEN --body "<new-token>"`.
3. Trigger `gh workflow run expiry-check.yml` (or wait for next
   Monday). Live API query returns the new expiry. Open issue
   auto-closes.

For `manual_expiry` items, also bump the date in
`.github/expiry-tracking.yml` and commit.

### 12.7 Watchdog

A scheduled workflow that errors out at startup creates an Actions-tab
failure but no issue — defeating the point. The included workflow has a
watchdog step that opens a `rotation-system-failure` issue if the main
job fails. So if the workflow itself is broken, you still get an issue
about the broken-watchdog, not silence.

---

## Quick reference — what each secret does

| Secret                      | Used by                                    | Phase set | Tracked by Phase 12?           |
| --------------------------- | ------------------------------------------ | --------- | ------------------------------ |
| `DEVELOPMENT_TEAM`          | xcodebuild, notarytool, sign.sh            | 1         | No (string, no expiry)         |
| `DEVELOPER_ID_IDENTITY`     | xcodebuild, sign.sh                        | 2         | No (string identity)           |
| `DEVELOPER_ID_P12_BASE64`   | notarize.yml keychain import               | 6         | Yes (via cert query)           |
| `DEVELOPER_ID_P12_PASSWORD` | notarize.yml security import               | 6         | Indirectly (rotates with cert) |
| `KEYCHAIN_PASSWORD`         | notarize.yml temp keychain                 | 6         | No (no expiry)                 |
| `APPSTORE_API_KEY_ID`       | notarize.sh + expiry-check.py              | 3         | Manual cadence                 |
| `APPSTORE_API_ISSUER_ID`    | notarize.sh + expiry-check.py              | 3         | Manual cadence                 |
| `APPSTORE_API_KEY_P8`       | notarize.sh + expiry-check.py              | 3         | Manual cadence                 |
| `SOJOURN_OAUTH_CLIENT_ID`   | Local.xcconfig at build time               | 4         | No (no expiry)                 |
| `HOMEBREW_TAP_TOKEN`        | publish-homebrew-cask.sh + expiry-check.py | 5         | Yes (via PAT query)            |

---

## See also

- [release.md](release.md) — release flow once setup is done.
- [decisions/0009-bundle-binary-policy.md](../decisions/0009-bundle-binary-policy.md)
  — why gitleaks/age/cosign ship in `Resources/bin/`.
- [decisions/0015-keyless-cosign-plugin-trust.md](../decisions/0015-keyless-cosign-plugin-trust.md)
  — the plugin-signing model Phase 10 prepares for.
- [reference/plugin-protocol.md](../reference/plugin-protocol.md) —
  manifest schema reference plugins must implement.
