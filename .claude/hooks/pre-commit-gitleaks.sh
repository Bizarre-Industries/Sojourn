#!/usr/bin/env bash
# pre-commit-gitleaks.sh — PreToolUse hook fired on Bash. Blocks
# `git commit` invocations when gitleaks finds a leak in the staged
# files. Per CLAUDE.md invariant 9: "gitleaks runs before every
# auto-commit. High-confidence provider-key findings (AWS, GitHub
# PAT, OpenAI, Stripe) cannot be bypassed for 5 seconds."
#
# Implementation:
# - Reads the proposed Bash command from stdin JSON.
# - Skips (exit 0) for any command that isn't `git commit ...`.
# - For commits: runs `gitleaks protect --staged` against the
#   currently-staged files.
# - On leak: emits permissionDecision=deny + the leak summary.
# - On clean: emits no output (allows the commit).
#
# Skips gracefully if jq or gitleaks aren't installed (logged to
# stderr, exit 0).

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-commit-gitleaks.sh: jq not found, skipping" >&2
  exit 0
fi

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "pre-commit-gitleaks.sh: gitleaks not found, skipping" >&2
  exit 0
fi

payload="$(cat)"

tool_name="$(echo "$payload" | jq -r '.tool_name // empty')"
command_str="$(echo "$payload" | jq -r '.tool_input.command // empty')"

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

# Match `git commit` only — not `git commit-tree`, not `git --work-tree
# ... commit ...` (rare; not worth the false-positive surface).
if ! echo "$command_str" | grep -qE '(^|[^a-zA-Z])git[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

# Skip if --no-verify is being used. CLAUDE.md disallows it
# (security review separately enforces). The general never-guess.sh
# already pattern-matches --no-verify in its watch_patterns.
if echo "$command_str" | grep -qE '(--no-verify|--no-gpg-sign)'; then
  exit 0
fi

# Find repo root (the hook runs from CLAUDE_PROJECT_DIR, but the
# user's commit may be from a subdir).
repo_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# `gitleaks protect --staged` checks only files in the index.
# Faster than a full repo scan and matches what's about to be
# committed.
leak_exit=0
leak_output="$(cd "$repo_root" && gitleaks protect --staged --no-banner 2>&1)" || leak_exit=$?

if [ "$leak_exit" -eq 0 ]; then
  exit 0
fi

# Trim to the most useful 30 lines so the deny payload doesn't dump
# the entire scan output back into Claude's context.
leak_summary="$(echo "$leak_output" | tail -30)"

reason="gitleaks blocked the commit. Findings:

${leak_summary}

To proceed:
1. Remove or rotate the leaked secret.
2. If the value is a synthetic placeholder, add a regex to
   .gitleaks.toml::[allowlist].regexes.
3. Re-stage the fix and retry the commit."

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
