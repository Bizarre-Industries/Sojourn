#!/usr/bin/env bash
# scripts/notarize.sh -- submit the DMG to Apple notary and staple.
# Requires env: APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, DEVELOPMENT_TEAM.

set -euo pipefail

DMG="${1:?usage: notarize.sh <path/to/Sojourn.dmg>}"

: "${APPLE_ID:?APPLE_ID is required}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required}"
: "${DEVELOPMENT_TEAM:?DEVELOPMENT_TEAM is required}"

echo "submitting $DMG to notary service..."
xcrun notarytool submit "$DMG" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$DEVELOPMENT_TEAM" \
  --wait \
  --timeout 30m

echo "stapling ticket to $DMG..."
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "notarization complete."
