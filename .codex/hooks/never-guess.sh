#!/usr/bin/env bash
# never-guess.sh — PreToolUse hook fired on Bash + WebFetch. Doesn't
# block. Injects an additionalContext reminder when the proposed action
# involves an external tool whose behavior may have drifted since the
# LLM's training cutoff, or matches a "I think this works" pattern.
#
# Per AGENTS.md: LLM training data drifts. Compilation passing is not
# correctness. This hook is a nudge, not a wall — Codex still acts,
# but with a reminder to verify upstream before relying on the action.
#
# Payload (stdin): JSON with tool_name, tool_input. Output (stdout):
# JSON with systemMessage when a reminder is warranted, otherwise
# nothing.

set -euo pipefail

# Read the hook payload. If `jq` isn't present, no-op (don't block the
# session over a missing dep — log the absence to stderr).
if ! command -v jq >/dev/null 2>&1; then
  echo "never-guess.sh: jq not found, skipping reminder injection" >&2
  exit 0
fi

payload="$(cat)"

# Most Bash calls are harmless probes. Avoid jq + regex-loop overhead
# unless the raw payload contains a token this hook can actually act on.
case "$payload" in
  *WebFetch*|*notarytool*|*stapler*|*codesign*|*sign_update*|*softwareupdate*|*gh\ release*|*gh\ repo*|*gh\ pr*|*gh\ issue*|*op\ item*|*op\ signout*|*defaults*|*PlistBuddy*|*SMAppService*|*launchctl*|*mas*|*container*|*curl*|*wget*|*--no-verify*|*rm\ -rf*|*git\ push*|*git\ reset*|*git\ tag\ -d*|*git\ branch\ -D*|*git\ rebase\ --abort*|*diskutil*|*sudo*|*chmod\ 777*|*chmod\ -R\ 777*)
    ;;
  *)
    exit 0
    ;;
esac

tool_name="$(echo "$payload" | jq -r '.tool_name // empty')"
command_str="$(echo "$payload" | jq -r '.tool_input.command // .tool_input.url // empty')"

if [ -z "$command_str" ]; then
  exit 0
fi

# Risky tool+flag combos. Trimmed 2026-05-04: previous version fired on
# every benign `brew --version`, `codesign -d`, `docker --version` call
# — pure noise during stage 4 helper work. Now only fires on operations
# that mutate state on disk, notary servers, GitHub, 1Password, or
# signing config. Read-only probes (--version, --help, list, -d) skip
# the reminder entirely.
declare -a watch_combos=(
  # Mutates Apple notary state
  "notarytool submit"
  "notarytool history"
  "stapler staple"
  "stapler validate"
  # Mutates code-signing state
  "codesign --remove-signature"
  "codesign --force"
  "codesign -f "
  "sign_update"
  # Mutates Apple software baseline
  "softwareupdate --install"
  "softwareupdate -i "
  # Mutates GitHub remote state
  "gh release delete"
  "gh release create"
  "gh repo delete"
  "gh pr merge"
  "gh pr close"
  "gh issue delete"
  # Mutates 1Password vault
  "op item delete"
  "op item create"
  "op item edit"
  "op signout"
  # Modifies macOS prefs (defaults read is fine)
  "defaults delete"
  "defaults import"
  "defaults write"
  # PlistBuddy mutation
  "PlistBuddy.*-c .*Set"
  "PlistBuddy.*-c .*Add"
  "PlistBuddy.*-c .*Delete"
  # Privileged-helper management
  "SMAppService"
  "launchctl bootstrap"
  "launchctl bootout"
  "launchctl unload"
  # mas state mutation (the broken signin path)
  "mas signin"
  "mas account"
  # Apple `container` runtime mutation
  "container run"
  "container start"
  "container stop"
  "container delete"
)

# Risky shell patterns regardless of tool — destructive or
# irreversible operations.
declare -a watch_patterns=(
  "curl.*\|.*sh"
  "wget.*\|.*sh"
  "--no-verify"
  "rm -rf"
  "git push.*--force"
  "git push.*-f([^a-zA-Z]|$)"
  "git reset --hard"
  "git tag -d"
  "git branch -D"
  "git rebase --abort"
  "diskutil eraseDisk"
  "diskutil eraseVolume"
  "sudo "
  "chmod 777"
  "chmod -R 777"
)

reminder=""

for c in "${watch_combos[@]}"; do
  if echo "$command_str" | grep -qE -- "$c"; then
    reminder="State-mutating operation detected: '${c}'. Before relying on this call, confirm: (1) the flag/subcommand is still spelled correctly in the current upstream version (\`<tool> --help\` or man page), (2) the operation is reversible OR a snapshot was taken first, (3) any required env vars / secrets are loaded from 1Password and not committed. If you can't verify, ask before running."
    break
  fi
done

for p in "${watch_patterns[@]}"; do
  if echo "$command_str" | grep -qE -- "$p"; then
    if [ -n "$reminder" ]; then
      reminder="${reminder} Additionally, the command matches a high-risk shell pattern ('${p}'). Confirm this is intended; the disk-bricking deny-list catches only the most catastrophic cases — '--force' / '-D' / 'reset --hard' destroy work without prompting."
    else
      reminder="Command matches a high-risk shell pattern ('${p}'). Confirm this is intended and reversible. The disk-bricking deny-list catches only catastrophic cases — '--force' / '-D' / 'reset --hard' destroy work without prompting."
    fi
    break
  fi
done

if [ -z "$reminder" ]; then
  exit 0
fi

# WebFetch-specific override: reminder is different — encourage breadth
# of sources rather than verifying flag behavior.
if [ "$tool_name" = "WebFetch" ]; then
  reminder="Single-source web fetch. If this is a load-bearing claim (decides architecture, security, or a release), cross-check against at least one other source before relying on it. Vendor blog posts can be aspirational; release notes and source code are authoritative."
fi

# Emit non-blocking reminder. Codex surfaces `systemMessage` for
# PreToolUse; no permissionDecision means allow.
jq -n --arg ctx "$reminder" '{ systemMessage: $ctx }'
