---
description: Fire the 5-member council on the current diff. Writes deliberation log to .claude/council-logs/.
---

Fire the full Sojourn council on the current diff per CLAUDE.md
"Council (the only gate)" trigger list.

Steps:

1. Run `git diff --stat` and `git status --short` to identify the
   change scope.
2. If nothing is staged or working-tree-modified, ask the user which
   commit range to review (e.g. `HEAD~3..HEAD`).
3. Determine which trigger fired:
   - new ADR creation
   - new external dependency (Brewfile / Package.swift / GH Actions / MCP)
   - breaking change to a `Service` actor's public API or persisted
     schema (Brewfile / generations / cooldowns.toml / prefs.toml /
     machines.toml)
   - code deletion >100 LOC in one commit
   - any change under `Sojourn/Secrets/`, `Sojourn/Policy/`, signing
     config, or `notarize.yml`
4. Spawn all 5 council subagents in parallel via the Agent tool with
   matching `subagent_type`:
   - `council-architect`
   - `council-security`
   - `council-devil-advocate`
   - `council-perf-skeptic`
   - `council-ux-critic`
5. Pass each member: the diff, the change description, the trigger
   that fired, pointers to the active plan + relevant ADRs +
   `lessons.md`.
6. Collect all 5 verdicts. Apply must-fix conditions inline.
7. Write the deliberation log to
   `.claude/council-logs/<YYYY-MM-DD>-<slug>.md` matching the format
   of the existing logs (Verdict, Conditions met before commit per
   member, Conditions deferred, Conditions rejected as theater,
   Risks acknowledged, File changes, Next action).
8. Surface a summary table to the user.

Stop after step 8 — the human decides whether to commit. Do not
auto-commit on behalf of the council.

If `$ARGUMENTS` is non-empty, treat it as additional context (e.g.
`/council "stage 4 MasHelper implementation"`).
