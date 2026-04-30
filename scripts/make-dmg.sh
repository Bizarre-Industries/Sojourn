#!/usr/bin/env bash
# scripts/make-dmg.sh -- build a distribution DMG using create-dmg.
# Invoked by .github/workflows/notarize.yml after codesign.

set -euo pipefail

APP="${1:?usage: make-dmg.sh <path/to/Sojourn.app>}"
OUTPUT="${2:-Sojourn.dmg}"

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "installing create-dmg..."
  brew install create-dmg
fi

rm -f "$OUTPUT"

create-dmg \
  --volname "Sojourn" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 120 \
  --icon "$(basename "$APP")" 160 200 \
  --hide-extension "$(basename "$APP")" \
  --app-drop-link 440 200 \
  --hdiutil-quiet \
  "$OUTPUT" \
  "$APP"

# Sign the DMG so Gatekeeper has a signature to verify against the
# stapled notarization ticket. Without this, `spctl --assess --type
# install` rejects with "source=no usable signature" even after
# stapling. Identity is the Developer ID Application cert (same as the
# .app bundle); when unset (local dev), skip gracefully.
if [[ -n "${DEVELOPER_ID_IDENTITY:-}" ]]; then
  codesign --force --sign "$DEVELOPER_ID_IDENTITY" \
    --timestamp \
    --options runtime \
    "$OUTPUT"
  echo "signed $OUTPUT with $DEVELOPER_ID_IDENTITY"
else
  echo "info: DEVELOPER_ID_IDENTITY not set; skipping DMG signing (local dev)."
fi

echo "created $OUTPUT"
