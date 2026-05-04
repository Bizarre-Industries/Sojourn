# Council Log: MCP Agent Tooling Parity Follow-Up

Date: 2026-05-04

## Trigger

Council review was requested for the project-local Codex/Claude tooling parity
follow-up. The active diff tightens command mirrors, hooks, agent-tooling
verification, and gitleaks workflow behavior. The Codex-to-Claude MCP entry was
not newly enabled in this diff; ADR-0027 remains the governing decision.

## Diff Under Review

- Tracked `.codex/commands/` mirrors for `council`, `regen`, and
  `stage-commit`.
- Updated Claude command text to keep command semantics aligned with Codex.
- Strengthened `scripts/verify-agent-tooling.sh` to parse configs, verify
  Codex/Claude command parity, require disabled-by-default Claude MCP semantics,
  and reject transient session-memory blocks in policy files.
- Kept `.codex/config.toml` project-scoped and disabled by default.
- Redacted gitleaks output in hooks, Makefile, and CI.
- Pinned the CI gitleaks tarball by SHA-256 before extraction.

## Votes

### Architect

Decision: No decision recorded.

Two architect review agents were dispatched. Both timed out and were closed
without returning a verdict. This log therefore cannot be used as a completed
architectural approval for an agent-tooling commit.

Required before commit:
- Re-run or replace the architect review if a future commit is blocked on this
  council record.
- Keep the bridge disabled by default and project-scoped per ADR-0027.

### Security

Decision: Reject until hardening and local gitleaks blockers were addressed.

Dissents:
- Full gitleaks scanning still failed on ignored local credentials.
- The initial bridge experiment left a risk of default-on peer MCP processes.
- Hooks and workflow logs needed redaction by default.

Resolution:
- `.codex/config.toml` requires `enabled = false` for the Claude bridge.
- The verifier fails if the bridge is enabled by default.
- Hooks, `make leaks`, and CI gitleaks runs redact findings.
- CI verifies the downloaded gitleaks archive with a pinned SHA-256.
- The local ignored credential file remains unresolved and blocks commit.

### Devil's Advocate

Decision: Reject until command semantics and docs made the opt-in boundary
clear.

Dissents:
- Command mirrors could drift silently.
- AGENTS/CLAUDE did not make the peer-agent bridge opt-in enough.
- Session-memory blocks had reappeared in policy files.

Resolution:
- `scripts/verify-agent-tooling.sh` now checks command semantic snippets in
  both `.claude/commands/` and `.codex/commands/`.
- `AGENTS.md` and `CLAUDE.md` explain that the Codex-to-Claude bridge is
  disabled by default and must not be committed as enabled.
- The verifier rejects both `<claude-mem-context>` blocks and observation-roster
  markers such as `get_observations([`.

### Perf Skeptic

Decision: Reject until default-on peer MCP behavior was removed.

Dissents:
- Enabling `claude mcp serve` by default can spawn persistent peer-agent
  processes and add idle memory cost.
- Recursive peer-agent calls are an avoidable lifecycle risk.

Resolution:
- The project MCP bridge stays disabled by default.
- `AGENTS.md` and `CLAUDE.md` forbid recursive peer MCP/council flows.
- The verifier makes `enabled = true` a hard failure.

### UX Critic

Decision: Reject until developer-facing recovery paths were clear and touched
UI surfaces fixed accessibility/recoverability problems.

Dissents:
- The bridge opt-in docs were too implicit.
- Helper revoke was too easy to trigger.
- The current-job accessibility grouping risked hiding the cancel action.

Resolution:
- Agent docs now state the bridge opt-in boundary directly.
- Packages helper revoke now uses a confirmation dialog.
- Jobs combines the current-job text cluster while leaving cancellation as a
  separate accessible control.

## Verification

- `scripts/verify-agent-tooling.sh` — pass.
- `rg -n "claude-mem-context|Memory Context|recent context|get_observations\(" AGENTS.md CLAUDE.md` — no matches.
- `git diff --check` — pass.
- `gitleaks dir --config=.gitleaks.toml --no-banner --redact -v` — fail on
  ignored local `Sojourn/Config/local.xcconfig` credential findings.

## Verdict

Do not commit this tooling follow-up yet. The local credential file must leave
the checkout or be sanitized, and a complete architect verdict should be
recorded if this log is used as the commit gate.
