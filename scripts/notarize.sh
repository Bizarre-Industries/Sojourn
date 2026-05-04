#!/usr/bin/env bash
set -euo pipefail

DMG="${1:?usage: notarize.sh <path/to/Sojourn.dmg>}"

: "${APPSTORE_API_KEY_ID:?required}"
: "${APPSTORE_API_ISSUER_ID:?required}"
: "${APPSTORE_API_KEY_P8:?required}"

KEY_FILE="$(mktemp -t sojourn-notary.XXXXXX)"
chmod 600 "$KEY_FILE"
printf '%s' "$APPSTORE_API_KEY_P8" > "$KEY_FILE"

SUBMIT_OUTPUT="$(mktemp -t sojourn-notarize.XXXXXX)"
chmod 600 "$SUBMIT_OUTPUT"
cleanup() {
  rm -P -f "$KEY_FILE"
  rm -f "$SUBMIT_OUTPUT"
}
trap cleanup EXIT

# `--output-format json` so we can extract the submission ID and inspect
# Apple's per-issue log if notarization comes back Invalid. Without
# this, the workflow dies at `stapler staple` with the opaque "Could
# not find base64 encoded ticket" error and no actionable diagnostics.
if ! xcrun notarytool submit "$DMG" \
  --key "$KEY_FILE" \
  --key-id "$APPSTORE_API_KEY_ID" \
  --issuer "$APPSTORE_API_ISSUER_ID" \
  --output-format json \
  --wait --timeout 30m \
  > "$SUBMIT_OUTPUT"
then
  echo "::group::Notary submission failed — fetching log"
  cat "$SUBMIT_OUTPUT" || true
  SUB_ID="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("id",""))' "$SUBMIT_OUTPUT" 2>/dev/null || true)"
  if [[ -n "$SUB_ID" ]]; then
    xcrun notarytool log "$SUB_ID" \
      --key "$KEY_FILE" \
      --key-id "$APPSTORE_API_KEY_ID" \
      --issuer "$APPSTORE_API_ISSUER_ID" || true
  fi
  echo "::endgroup::"
  exit 1
fi

# `--wait` exits 0 even when status=Invalid. Check explicitly.
STATUS="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("status",""))' "$SUBMIT_OUTPUT" 2>/dev/null || echo "")"
SUB_ID="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("id",""))' "$SUBMIT_OUTPUT" 2>/dev/null || echo "")"
if [[ "$STATUS" != "Accepted" ]]; then
  echo "::group::Notarization status=$STATUS — fetching log"
  if [[ -n "$SUB_ID" ]]; then
    xcrun notarytool log "$SUB_ID" \
      --key "$KEY_FILE" \
      --key-id "$APPSTORE_API_KEY_ID" \
      --issuer "$APPSTORE_API_ISSUER_ID" || true
  fi
  echo "::endgroup::"
  exit 1
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
