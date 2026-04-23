#!/usr/bin/env bash
# scripts/publish-homebrew-cask.sh -- bump Sojourn's cask in the tap repo.
# Invoked from notarize.yml after release upload.
# Requires env: HOMEBREW_TAP_TOKEN.

set -euo pipefail

VERSION="${1:?usage: publish-homebrew-cask.sh <version>}"

: "${HOMEBREW_TAP_TOKEN:?HOMEBREW_TAP_TOKEN is required}"

echo "publishing homebrew-sojourn cask for ${VERSION} -- stub; wire up tap repo path."
