#!/usr/bin/env bash
# Sojourn — regenerate Sojourn.xcodeproj from project.yml
# Run after modifying project.yml or adding/removing source files.
# See docs/IMPLEMENTATION_PLAN.md Phase 0.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Error: xcodegen not found. Install via: brew install xcodegen"
  exit 1
fi

echo "Regenerating Sojourn.xcodeproj from project.yml..."
xcodegen generate

echo "Resolving SPM dependencies..."
xcodebuild -resolvePackageDependencies -project Sojourn.xcodeproj -scheme Sojourn

echo "Done. Open Sojourn.xcodeproj in Xcode."
