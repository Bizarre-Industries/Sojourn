#!/usr/bin/env bash
# scripts/publish-homebrew-cask.sh -- bump Sojourn's cask in the tap repo.
# Invoked from notarize.yml after release upload.
#
# Flow:
#   1. Clone Bizarre-Industries/homebrew-sojourn into a temp dir.
#   2. Re-template Casks/sojourn.rb with new version + URL + SHA256.
#   3. Commit and push.
#
# Required env:
#   HOMEBREW_TAP_TOKEN  -- fine-grained PAT with write access to the tap
#   GITHUB_REPOSITORY   -- set by Actions; fallback to Bizarre-Industries/Sojourn
#
# Positional:
#   $1 = version tag, e.g. v0.1.0

set -euo pipefail

VERSION="${1:?usage: publish-homebrew-cask.sh <version>}"
VERSION_BARE="${VERSION#v}"

: "${HOMEBREW_TAP_TOKEN:?HOMEBREW_TAP_TOKEN is required}"

UPSTREAM_REPO="${GITHUB_REPOSITORY:-Bizarre-Industries/Sojourn}"
TAP_REPO="Bizarre-Industries/homebrew-sojourn"
DMG_NAME="Sojourn.dmg"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DMG_PATH="${SOJOURN_DMG_PATH:-${DMG_NAME}}"
if [[ ! -f "$DMG_PATH" ]]; then
  echo "ERROR: DMG not found at $DMG_PATH"
  exit 1
fi

DMG_SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
DMG_URL="https://github.com/${UPSTREAM_REPO}/releases/download/${VERSION}/${DMG_NAME}"

echo "cloning tap repo..."
git clone --depth 1 "https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/${TAP_REPO}.git" "$TMP/tap"

CASK_PATH="$TMP/tap/Casks/sojourn.rb"
mkdir -p "$(dirname "$CASK_PATH")"

cat >"$CASK_PATH" <<EOF
cask "sojourn" do
  version "${VERSION_BARE}"
  sha256 "${DMG_SHA}"

  url "${DMG_URL}"
  name "Sojourn"
  desc "Cross-Mac setup sync via mpm + chezmoi + defaults"
  homepage "https://github.com/${UPSTREAM_REPO}"

  depends_on macos: ">= :sonoma"

  app "Sojourn.app"

  zap trash: [
    "~/Library/Application Support/Sojourn",
    "~/Library/Preferences/app.bizarre.sojourn.plist",
    "~/Library/Caches/app.bizarre.sojourn",
  ]
end
EOF

cd "$TMP/tap"
git config user.email "release-bot@bizarre.app"
git config user.name "Sojourn Release Bot"
git add Casks/sojourn.rb
if git diff --cached --quiet; then
  echo "no cask changes; skipping commit"
  exit 0
fi

git commit -s -m "sojourn: bump to ${VERSION_BARE}"
git push origin HEAD:main
echo "published sojourn ${VERSION_BARE} to ${TAP_REPO}"
