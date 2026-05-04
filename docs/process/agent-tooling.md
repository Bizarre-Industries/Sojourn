# Agent Tooling

Sojourn uses one shared agent contract and two project-specific tool
surfaces. ADR-0027 records the decision.

- `AGENTS.md` is the agent-agnostic source of truth.
- `CLAUDE.md` is the Claude Code mirror.
- `.claude/` contains Claude Code settings, hooks, commands, and
  Markdown subagents.
- `.codex/` contains Codex config, hooks, and TOML subagents.
- `.claude/skills/` and `.agents/skills/` are mirrors. Claude Code
  reads the former; Codex reads the latter.

## MCP Bridge

The project keeps the Codex/Claude bridge explicit:

- Claude Code can call Codex through `.mcp.json` via the `codex`
  project-scoped MCP server. Claude Code prompts before using
  project-scoped MCP servers.
- Codex can call Claude Code through the disabled
  `.codex/config.toml::mcp_servers.claude_code` entry. Enable it only
  for a deliberate bridge session, then restart Codex.
- Do not put project-specific peer-agent wrappers in
  `~/.codex/config.toml`; a global bridge must be generic and disabled
  by default so one repo cannot inherit another repo's policy scripts.

Do not add or enable third-party MCP servers casually. A new MCP server
is a new external dependency under the council trigger list in
`AGENTS.md`.

## Verification

Run this before committing agent tooling changes:

```sh
bash scripts/verify-agent-tooling.sh
```

That script checks JSON/TOML syntax, hook executability, required CLI
availability, and `.claude/skills` versus `.agents/skills` drift.
