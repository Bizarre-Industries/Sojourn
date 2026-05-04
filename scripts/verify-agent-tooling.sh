#!/usr/bin/env bash
# Verify the project-local Claude Code and Codex agent/tooling config.

set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

python3 - <<'PY'
import json
import pathlib
import tomllib

for path in [
    ".claude/settings.json",
    ".codex/hooks.json",
    ".mcp.json",
]:
    with open(path, "rb") as handle:
        json.load(handle)

for path in [".codex/config.toml", *sorted(str(p) for p in pathlib.Path(".codex/agents").glob("*.toml"))]:
    with open(path, "rb") as handle:
        tomllib.load(handle)
PY

for tool in codex claude; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "FATAL: required CLI not found on PATH: $tool" >&2
    exit 1
  fi
done

for hook in .claude/hooks/*.sh .codex/hooks/*.sh scripts/sign-sparkle.sh; do
  if [[ ! -x "$hook" ]]; then
    echo "FATAL: hook/script is not executable: $hook" >&2
    exit 1
  fi
done

if ! diff -qr .claude/skills .agents/skills >/tmp/sojourn-skill-diff.$$; then
  cat /tmp/sojourn-skill-diff.$$
  rm -f /tmp/sojourn-skill-diff.$$
  echo "FATAL: .claude/skills and .agents/skills drifted" >&2
  exit 1
fi
rm -f /tmp/sojourn-skill-diff.$$

for agent in council-architect council-devil-advocate council-perf-skeptic council-security council-ux-critic mechanical self-critique; do
  test -f ".claude/agents/${agent}.md"
  test -f ".codex/agents/${agent}.toml"
done

echo "agent tooling verified"
