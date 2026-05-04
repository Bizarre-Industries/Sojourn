#!/usr/bin/env bash
# mark-replanned.sh <tag> — called by Claude after the next-version
# plan file has been rewritten and the first execution-step commit has
# landed. Advances .codex/.last-shipped-tag so the SessionStart +
# Stop hook stops re-prompting.

set -euo pipefail

tag="${1:?usage: mark-replanned.sh <tag>}"
repo="${CODEX_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"

mkdir -p "$repo/.codex"
echo "$tag" > "$repo/.codex/.last-shipped-tag"
echo "marked replanned at $tag"
