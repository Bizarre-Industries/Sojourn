#!/usr/bin/env bash
# scripts/download-bundled-bins.sh -- fetch gitleaks and age for bundling.
# Uses gh CLI for authenticated GitHub release download.
# Checksums MUST be updated on version bump.

set -euo pipefail

BIN_DIR="Sojourn/Resources/bin"
mkdir -p "$BIN_DIR"

GITLEAKS_VERSION="8.30.1"
AGE_VERSION="1.2.1"

ARCH="$(uname -m)"
case "$ARCH" in
  arm64)
    GLEAKS_ASSET="gitleaks_${GITLEAKS_VERSION}_darwin_arm64.tar.gz"
    AGE_ASSET="age-v${AGE_VERSION}-darwin-arm64.tar.gz"
    ;;
  x86_64)
    GLEAKS_ASSET="gitleaks_${GITLEAKS_VERSION}_darwin_x64.tar.gz"
    AGE_ASSET="age-v${AGE_VERSION}-darwin-amd64.tar.gz"
    ;;
  *)
    echo "unsupported arch: $ARCH"
    exit 1
    ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "downloading gitleaks ${GITLEAKS_VERSION}..."
gh release download "v${GITLEAKS_VERSION}" \
  --repo gitleaks/gitleaks \
  --pattern "${GLEAKS_ASSET}" \
  --dir "$TMP"
tar -xzf "$TMP/${GLEAKS_ASSET}" -C "$TMP" gitleaks
mv "$TMP/gitleaks" "$BIN_DIR/gitleaks"
chmod +x "$BIN_DIR/gitleaks"

echo "downloading age ${AGE_VERSION}..."
gh release download "v${AGE_VERSION}" \
  --repo FiloSottile/age \
  --pattern "${AGE_ASSET}" \
  --dir "$TMP"
tar -xzf "$TMP/${AGE_ASSET}" -C "$TMP"
mv "$TMP/age/age" "$BIN_DIR/age"
chmod +x "$BIN_DIR/age"

echo "downloaded and extracted to $BIN_DIR"
