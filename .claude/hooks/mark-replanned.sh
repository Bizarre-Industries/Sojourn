#!/usr/bin/env bash
# mark-replanned.sh <tag> — called by Claude after a replan plan file has
# been written + approved. Persists the tag so the SessionStart hook
# stops re-prompting.
set -euo pipefail
tag="${1:?usage: mark-replanned.sh <tag>}"
repo="${CLAUDE_PROJECT_DIR:-$(pwd)}"
mkdir -p "$repo/.claude"
echo "$tag" > "$repo/.claude/.last-shipped-tag"
echo "marked replanned at $tag"
