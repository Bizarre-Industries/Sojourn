#!/usr/bin/env bash
# scripts/sign-sparkle.sh -- trim and re-sign Sparkle for Developer ID distribution.
#
# Xcode's regular build signs Sparkle.framework itself, but the direct
# xcodebuild release path does not archive/export the app. Sparkle's
# documentation says that non-archive distribution workflows must
# re-sign Sparkle's helper tools explicitly before the framework and
# app are sealed for notarization. Sojourn is not sandboxed and does
# not enable Sparkle's sandbox XPC services, so trim those services
# before signing to reduce the release attack surface.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: scripts/sign-sparkle.sh <path-to-app>" >&2
  exit 64
fi

if [[ -z "${DEVELOPER_ID_IDENTITY:-}" ]]; then
  echo "info: DEVELOPER_ID_IDENTITY not set; skipping Sparkle signing (local dev)."
  exit 0
fi

APP_PATH="$1"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
SPARKLE_VERSION="$SPARKLE_FRAMEWORK/Versions/Current"

if [[ ! -d "$APP_PATH" ]]; then
  echo "FATAL: app bundle not found: $APP_PATH" >&2
  exit 66
fi

if [[ ! -d "$SPARKLE_VERSION" ]]; then
  echo "FATAL: Sparkle.framework not found in app bundle: $SPARKLE_FRAMEWORK" >&2
  exit 66
fi

plist_bool() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null || true
}

installer_service="$(plist_bool SUEnableInstallerLauncherService)"
downloader_service="$(plist_bool SUEnableDownloaderService)"

if [[ "$installer_service" == "true" || "$downloader_service" == "true" ]]; then
  echo "FATAL: Sojourn release script trims Sparkle XPC services, but Info.plist enables one." >&2
  echo "FATAL: Update scripts/sign-sparkle.sh before enabling Sparkle sandbox XPC services." >&2
  exit 65
fi

for path in "$SPARKLE_VERSION/XPCServices" "$SPARKLE_FRAMEWORK/XPCServices"; do
  if [[ -e "$path" || -L "$path" ]]; then
    echo "removing unused Sparkle sandbox XPC services: $path"
    rm -rf "$path"
  fi
done

sign_runtime() {
  local path="$1"
  shift

  if [[ ! -e "$path" ]]; then
    echo "FATAL: required Sparkle component missing: $path" >&2
    exit 66
  fi

  echo "signing $path"
  codesign \
    --force \
    --sign "$DEVELOPER_ID_IDENTITY" \
    --options runtime \
    --timestamp \
    "$@" \
    "$path"
  codesign --verify --strict --verbose=2 "$path"
}

sign_runtime "$SPARKLE_VERSION/Autoupdate"
sign_runtime "$SPARKLE_VERSION/Updater.app"
sign_runtime "$SPARKLE_FRAMEWORK"

# Re-seal the outer app after mutating nested framework contents.
echo "re-signing app bundle after Sparkle nested signing"
codesign \
  --force \
  --sign "$DEVELOPER_ID_IDENTITY" \
  --options runtime \
  --timestamp \
  --preserve-metadata=entitlements,requirements \
  "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
