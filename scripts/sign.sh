#!/usr/bin/env bash
# scripts/sign.sh -- re-sign bundled binaries with Developer ID + hardened runtime.
# Invoked by .github/workflows/notarize.yml before xcodebuild.
# Requires env: DEVELOPER_ID_IDENTITY.

set -euo pipefail

: "${DEVELOPER_ID_IDENTITY:?DEVELOPER_ID_IDENTITY is required}"

BIN_DIR="Sojourn/Resources/bin"

if [[ ! -d "$BIN_DIR" ]]; then
  echo "error: $BIN_DIR not found. Run scripts/download-bundled-bins.sh first."
  exit 1
fi

for binary in "$BIN_DIR"/gitleaks "$BIN_DIR"/age; do
  if [[ ! -f "$binary" ]]; then
    echo "warn: $binary missing, skipping"
    continue
  fi
  echo "signing $binary"
  codesign \
    --force \
    --sign "$DEVELOPER_ID_IDENTITY" \
    --options runtime \
    --timestamp \
    --verbose=2 \
    "$binary"
  codesign --verify --strict --verbose=2 "$binary"
done

echo "all bundled binaries signed."
