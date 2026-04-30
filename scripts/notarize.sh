#!/usr/bin/env bash
set -euo pipefail

DMG="${1:?usage: notarize.sh <path/to/Sojourn.dmg>}"

: "${APPSTORE_API_KEY_ID:?required}"
: "${APPSTORE_API_ISSUER_ID:?required}"
: "${APPSTORE_API_KEY_P8:?required}"

KEY_FILE="$(mktemp -t sojourn-notary.XXXX).p8"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$APPSTORE_API_KEY_P8" > "$KEY_FILE"

xcrun notarytool submit "$DMG" \
  --key "$KEY_FILE" \
  --key-id "$APPSTORE_API_KEY_ID" \
  --issuer "$APPSTORE_API_ISSUER_ID" \
  --wait --timeout 30m

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"