#!/usr/bin/env bash
# replan-on-ship.sh — fires on SessionStart + Stop. If a v* tag exists
# that the marker file hasn't seen, emit a hookSpecificOutput
# additionalContext nudging Claude to reanalyze and write a new plan
# toward the next version.
#
# Idempotent: only the first session after a new ship is prompted.
# After Claude writes the new plan and the user approves, Claude runs
# `bash .claude/hooks/mark-replanned.sh <tag>` to advance the marker.

set -euo pipefail

repo="${CLAUDE_PROJECT_DIR:-$(pwd)}"
marker="$repo/.claude/.last-shipped-tag"
mkdir -p "$repo/.claude"
touch "$marker"
last_seen="$(cat "$marker")"

# Only act inside a git repo.
if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

latest_tag="$(git -C "$repo" tag -l 'v*' --sort=-creatordate | head -n1 || true)"

if [ -z "$latest_tag" ]; then
  exit 0  # no tags yet
fi

if [ "$latest_tag" = "$last_seen" ]; then
  exit 0  # already replanned for this ship
fi

# Detect channel from event payload to scope the additionalContext key.
event_name="SessionStart"
if [ -n "${CLAUDE_HOOK_EVENT:-}" ]; then
  event_name="$CLAUDE_HOOK_EVENT"
fi

plan_path="/Users/binghzal/.claude/plans/sojourn-post-${latest_tag}.md"

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "${event_name}",
    "additionalContext": "Sojourn shipped tag ${latest_tag}. Reanalyze the repo + docs/specs/plans + CHANGELOG and write a new plan to ${plan_path} targeting the next version per docs/process/implementation-plan.md phase ladder. After writing the plan and getting user approval to start, run: bash .claude/hooks/mark-replanned.sh ${latest_tag}"
  }
}
EOF
