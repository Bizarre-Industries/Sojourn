# Council log — release signing and agent tooling

- **Date**: 2026-05-04
- **Trigger**: touched `.github/workflows/notarize.yml`; added project
  MCP bridge config; added ADR-0027.
- **Scope**: v0.3 release-signing fix, hosted SwiftPM watchdog test
  stabilization, Codex/Claude project tooling sync.

## Verdict

Accepted with amendments. Split landing into separate commits:

1. hosted SwiftPM watchdog test stabilization;
2. Sparkle release-signing/notarization fix;
3. project agent-tooling bridge and mirrors.

## Votes

### Architect

**Decision**: APPROVE-WITH-CONDITIONS.

Conditions:

- Do not commit untriaged v0.4 autoplan scaffold with release/tooling
  changes.
- Fix gitleaks hook bypass behavior.
- Make Sparkle signing fail closed when release-required Sparkle
  artifacts are absent.
- Record council coverage for the MCP bridge and note why it is
  developer tooling, not product runtime architecture.

### Security

**Decision**: APPROVE-WITH-CONDITIONS.

Conditions:

- Remove broad `.claude/.*` and `.agents/.*` gitleaks allowlists before
  tracking agent trees.
- Make commit hooks fail closed for commit commands if `jq` or
  `gitleaks` is missing.
- Remove session memory context from `AGENTS.md`.
- Re-run gitleaks after narrowing allowlists.

### Devil's advocate

**Decision**: REJECT as a single commit.

Dissents:

- Signing, test stabilization, and agent tooling should not be bundled.
- Sojourn is not sandboxed and does not enable Sparkle XPC service
  Info.plist keys; trim unused Sparkle XPC services instead of shipping
  and signing them.
- Do not land MCP bridge without ADR/plan-backed rationale.
- Keep `v0.4-plan.md` out of release/tooling commits until rewritten.

### Perf skeptic

**Decision**: APPROVE-WITH-CONDITIONS.

Conditions:

- Add a step timeout to Sparkle signing.
- Reduce `never-guess.sh` no-op overhead before enabling Codex hooks by
  default.

### UX critic

**Decision**: REJECT until developer-facing workflow is understandable.

Conditions:

- Remove stale memory context from `AGENTS.md`.
- Fix or exclude broken v0.4 autoplan scaffold.
- Fix replan hook generation of prior plan path and next-version labels.
- Add or correct this council-log reference.
- Add recovery instructions to missing-tool hook denial messages.

## Amendments Applied

- `scripts/sign-sparkle.sh` now removes Sparkle sandbox-only XPC services
  for Sojourn's non-sandboxed release, fails if the app enables those
  services, signs `Autoupdate`, `Updater.app`, `Sparkle.framework`, and
  re-seals the outer app.
- `.github/workflows/notarize.yml` calls the Sparkle trim/sign step
  before DMG creation and caps it at 10 minutes.
- Codex and Claude gitleaks hooks deny `--no-verify` and fail closed for
  commit commands when `jq` or `gitleaks` is unavailable.
- `never-guess.sh` has a fast raw-payload prefilter; no-op Bash hook
  smoke is below 50 ms locally.
- `.gitleaks.toml` no longer allowlists `.claude/.*` or `.agents/.*`;
  the Apple app-specific password heuristic was narrowed to avoid
  hyphenated documentation slugs.
- `AGENTS.md` is clean policy text; no session memory context remains.
- ADR-0027 records project-scoped agent bridges and opt-in defaults.
- Replan hooks now scaffold from `docs/process/plans/v<major>.<minor>-plan.md`
  and use `v<major>.<next-minor+1>` labels for open questions.

## Verification

- `bash scripts/verify-agent-tooling.sh` — pass.
- `bash -n .codex/hooks/*.sh .claude/hooks/*.sh scripts/sign-sparkle.sh
  scripts/verify-agent-tooling.sh` — pass.
- Hook smoke: `--no-verify` commit payload denied by both Codex and
  Claude hooks.
- Hook smoke: missing `gitleaks` on PATH denies commit with recovery
  instructions.
- Sparkle trim/sign smoke with a fake `codesign` and framework fixture —
  pass; XPC services removed and required helpers signed.
- `gitleaks dir --config=.gitleaks.toml --no-banner --redact -v` — pass.
- `swift build` — pass.
- `swift test` — pass, 152 tests.
- `make ci-local` — pass; SwiftLint and swift-format remain advisory.

## Sources

- Sparkle sandboxing and manual signing:
  https://sparkle-project.org/documentation/sandboxing/
- Sparkle security and reliability notes:
  https://sparkle-project.org/documentation/security-and-reliability/
- OpenAI Codex hooks:
  https://developers.openai.com/codex/hooks
- OpenAI Codex MCP:
  https://developers.openai.com/codex/mcp
- Anthropic Claude Code MCP:
  https://docs.anthropic.com/en/docs/claude-code/mcp
