#!/usr/bin/env bash
# scripts/sign.sh -- re-sign bundled binaries with Developer ID + hardened runtime.
# Invoked by .github/workflows/notarize.yml before xcodebuild, and as a
# preBuildScript in project.yml. Requires env: DEVELOPER_ID_IDENTITY.
#
# For local Debug builds where DEVELOPER_ID_IDENTITY is unset, we skip
# gracefully so the scheme builds without a dev cert. Release workflows
# always set the var and perform real signing.

set -euo pipefail

if [[ -z "${DEVELOPER_ID_IDENTITY:-}" ]]; then
  echo "info: DEVELOPER_ID_IDENTITY not set; skipping bundled-binary signing (local dev)."
  exit 0
fi

# First positional arg (if any) overrides the default bin dir. The Xcode
# preBuildScript passes the path to Contents/Resources/bin in the built app.
BIN_DIR="${1:-Sojourn/Resources/bin}"

if [[ ! -d "$BIN_DIR" ]]; then
  echo "info: $BIN_DIR not found; nothing to sign (run scripts/download-bundled-bins.sh for release)."
  exit 0
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
