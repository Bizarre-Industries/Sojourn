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

echo "created $OUTPUT"
