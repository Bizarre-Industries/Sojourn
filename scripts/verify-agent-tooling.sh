#!/usr/bin/env bash
# Verify the project-local Claude Code and Codex agent/tooling config.

set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

python3 - <<'PY'
import json
import pathlib
import tomllib

root = pathlib.Path(".")

for path in ["AGENTS.md", "CLAUDE.md"]:
    text = root.joinpath(path).read_text()
    if "<claude-mem-context>" in text:
        raise SystemExit(f"FATAL: {path} contains transient Claude memory context")
    if "get_observations([" in text or "# [Sojourn] recent context" in text:
        raise SystemExit(f"FATAL: {path} contains transient session observation context")

agents_lines = root.joinpath("AGENTS.md").read_text().splitlines()
claude_lines = root.joinpath("CLAUDE.md").read_text().splitlines()
if agents_lines[7:] != claude_lines[7:]:
    raise SystemExit("FATAL: AGENTS.md and CLAUDE.md drifted outside their intentional header wording")

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

with open(".mcp.json", "rb") as handle:
    mcp = json.load(handle)
if "codex" not in mcp.get("mcpServers", {}):
    raise SystemExit("FATAL: .mcp.json must expose Codex to Claude")

with open(".codex/config.toml", "rb") as handle:
    codex_config = tomllib.load(handle)
claude_server = codex_config.get("mcp_servers", {}).get("claude_code", {})
if claude_server.get("command") != "claude" or claude_server.get("args") != ["mcp", "serve"]:
    raise SystemExit("FATAL: .codex/config.toml must configure a disabled project-scoped Claude Code MCP entry")
if claude_server.get("enabled") is not False:
    raise SystemExit("FATAL: .codex/config.toml claude_code MCP must stay disabled by default; do not commit enabled = true")

command_requirements = {
    "council": [
        "git diff --stat",
        "council-architect",
        "council-security",
        "council-devil-advocate",
        "council-perf-skeptic",
        "council-ux-critic",
        "parallel",
        "council-logs",
    ],
    "regen": [
        "xcodegen generate",
        "Sojourn.xcodeproj/project.pbxproj",
        "swift build",
        "CURRENT_PROJECT_VERSION",
        "MARKETING_VERSION",
    ],
    "stage-commit": [
        "gitleaks dir --config=.gitleaks.toml --redact --no-banner",
        "swift build",
        "xcodebuild test -project Sojourn.xcodeproj -scheme Sojourn",
        "self-critique",
        "git commit -s",
        "--no-verify",
    ],
}
for command, required_snippets in command_requirements.items():
    for prefix in [".claude", ".codex"]:
        text = root.joinpath(prefix, "commands", f"{command}.md").read_text()
        missing = [snippet for snippet in required_snippets if snippet not in text]
        if missing:
            raise SystemExit(f"FATAL: {prefix}/commands/{command}.md is missing command semantics: {missing}")
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

for command in council regen stage-commit; do
  test -f ".claude/commands/${command}.md"
  test -f ".codex/commands/${command}.md"
done

echo "agent tooling verified"
