#!/usr/bin/env bash
# scripts/download-bundled-bins.sh -- fetch gitleaks and age for bundling.
# Uses gh CLI for authenticated GitHub release download.
#
# Each asset is verified against a pinned SHA256 before being moved into
# `Sojourn/Resources/bin/`. On version bump, update both the *_VERSION
# variable and the corresponding CHECKSUM entry. If CHECKSUM is set to
# "TBD" a warning is logged and the download proceeds — acceptable only
# for local dev iteration, never CI (set STRICT_CHECKSUMS=1 to fail hard).

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
    # Pinned 2026-04-24 from upstream gitleaks_${GITLEAKS_VERSION}_checksums.txt
    # + shasum -a 256 on age-${AGE_VERSION} tarball (age ships no checksum file).
    GLEAKS_SHA256="b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5"
    AGE_SHA256="cf79875bd5970dc2dac60c87fa50cee1ff1f9a41b0eb273f65e174aff37c367a"
    ;;
  x86_64)
    GLEAKS_ASSET="gitleaks_${GITLEAKS_VERSION}_darwin_x64.tar.gz"
    AGE_ASSET="age-v${AGE_VERSION}-darwin-amd64.tar.gz"
    GLEAKS_SHA256="dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709"
    AGE_SHA256="424e1d64438a730626540b2e01e98d132a64214442ca9465b3e82336d12e633e"
    ;;
  *)
    echo "unsupported arch: $ARCH"
    exit 1
    ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

verify_sha() {
  local file="$1"
  local expected="$2"
  local name
  name="$(basename "$file")"
  if [[ "$expected" == "TBD" ]]; then
    if [[ "${STRICT_CHECKSUMS:-0}" == "1" ]]; then
      echo "ERROR: SHA256 not pinned for $name and STRICT_CHECKSUMS=1"
      exit 1
    fi
    echo "WARNING: SHA256 not pinned for $name -- update scripts/download-bundled-bins.sh before release"
    return 0
  fi
  local actual
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: SHA256 mismatch for $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    exit 1
  fi
  echo "SHA256 verified: $name"
}

echo "downloading gitleaks ${GITLEAKS_VERSION}..."
gh release download "v${GITLEAKS_VERSION}" \
  --repo gitleaks/gitleaks \
  --pattern "${GLEAKS_ASSET}" \
  --dir "$TMP"
verify_sha "$TMP/${GLEAKS_ASSET}" "$GLEAKS_SHA256"
tar -xzf "$TMP/${GLEAKS_ASSET}" -C "$TMP" gitleaks
mv "$TMP/gitleaks" "$BIN_DIR/gitleaks"
chmod +x "$BIN_DIR/gitleaks"

echo "downloading age ${AGE_VERSION}..."
gh release download "v${AGE_VERSION}" \
  --repo FiloSottile/age \
  --pattern "${AGE_ASSET}" \
  --dir "$TMP"
verify_sha "$TMP/${AGE_ASSET}" "$AGE_SHA256"
tar -xzf "$TMP/${AGE_ASSET}" -C "$TMP"
mv "$TMP/age/age" "$BIN_DIR/age"
chmod +x "$BIN_DIR/age"

echo "downloaded and extracted to $BIN_DIR"
