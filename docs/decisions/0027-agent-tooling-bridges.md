# 0027 — Project-scoped agent tooling bridges

- **Status**: Accepted
- **Date**: 2026-05-04
- **Deciders**: Maintainer (skalghazali); Sojourn council (architect,
  security, devil-advocate, perf-skeptic, ux-critic).

## Context

Sojourn is worked on by both Codex and Claude Code. Before this
decision, the repo had partial agent config in `.claude/`, untracked
Codex config in `.codex/`, and a plugin-managed `.agents/` tree that
was ignored even though Codex reads project skills from `.agents/skills`.
The global Codex MCP config also pointed a `claude-code` bridge at a
different repository, so Sojourn could inherit another project's peer
agent wrapper.

The user explicitly asked for Codex hooks, agents, skills, settings,
tools, MCP servers, and Claude configs to be made coherent and kept in
sync.

## Decision

Sojourn keeps agent tooling project-scoped and opt-in:

1. `AGENTS.md` is the agent-agnostic policy source.
2. `CLAUDE.md` remains the Claude Code mirror because Claude loads that
   filename natively.
3. `.claude/skills/` and `.agents/skills/` are tracked mirrors. Claude
   Code reads the former; Codex reads the latter.
4. `.claude/agents/*.md` and `.codex/agents/*.toml` are tracked mirrors
   by role, not byte-identical files.
5. Claude Code may call Codex through project `.mcp.json`, which exposes
   `codex mcp-server`.
6. Codex may call Claude Code through `.codex/config.toml`, but that
   bridge is disabled by default and must be enabled deliberately for a
   bridge session.
7. Global Codex config must not point at repository-specific peer-agent
   wrappers. Any global bridge is generic and disabled by default.

`scripts/verify-agent-tooling.sh` is the local guardrail: it parses the
JSON/TOML configs, verifies executable hook scripts, checks both CLIs are
available, and fails if `.claude/skills` and `.agents/skills` drift.

## Consequences

### Positive

- Codex and Claude Code now read the same project policy, skills, and
  council roles.
- Agent bridges do not silently start recursive peer-agent sessions.
- Sojourn no longer inherits another repo's global MCP wrapper.
- The tracked skill mirror makes Codex behavior reproducible across
  clones instead of depending on ignored plugin cache state.

### Negative

- The skill mirror adds review noise and repository size.
- Role mirrors are semantic, not byte-identical; reviewers must keep
  `.claude/agents` and `.codex/agents` aligned manually.
- Project `.mcp.json` exposes a PATH-resolved `codex` executable to
  Claude Code. Claude still prompts before use, but this is an explicit
  execution surface.

### Neutral

- This is agent/developer tooling only. It does not change Sojourn's
  runtime architecture, user data model, subprocess boundaries, or app
  update mechanism.
- No third-party MCP server is added. The committed project bridge uses
  the already-installed Codex CLI.

## Alternatives considered

- **Keep `.agents/` ignored** — rejected. Codex then depends on
  per-machine plugin cache state and cannot reliably use the project
  skills required by `AGENTS.md`.
- **Enable Codex-to-Claude by default** — rejected. It risks recursive
  agent loops and adds startup/process lifecycle cost to every Codex
  session.
- **Use only global MCP config** — rejected. The prior global bridge
  already drifted to a different repo. Sojourn policy belongs in the
  Sojourn repo.
- **Add third-party MCP servers now** — rejected. Current installed MCPs
  already cover GitHub, Xcode, Context7, OpenAI docs, and browser use.
  New third-party servers would need separate threat review and a clear
  workflow gap.

## Council amendments

- Split agent tooling from release-signing commits so rollback is
  narrow.
- Remove broad `.claude/.*` and `.agents/.*` gitleaks allowlists before
  tracking the agent trees.
- Make gitleaks commit hooks fail closed for commit commands when
  required scanner/parser tools are missing.
- Do not commit untriaged autoplan scaffolds with agent-tooling changes.

### Council log

`.codex/council-logs/2026-05-04-release-signing-and-agent-tooling.md`.
