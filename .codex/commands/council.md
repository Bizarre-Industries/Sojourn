---
description: Fire the 5-member council on the current diff. Writes deliberation log to .codex/council-logs/.
---

Fire the full Sojourn council on the current diff per `AGENTS.md`
"Council (the only gate)" trigger list.

Steps:

1. Run `git diff --stat` and `git status --short` to identify the
   change scope.
2. If nothing is staged or working-tree-modified, ask the user which
   commit range to review.
3. Determine which trigger fired:
   - new ADR creation
   - new external dependency
   - breaking change to a `Service` actor public API or persisted schema
   - code deletion over 100 LOC in one commit
   - change under `Sojourn/Secrets/`, `Sojourn/Policy/`, signing config,
     or `notarize.yml`
4. Spawn all five council subagents in parallel:
   - `council-architect`
   - `council-security`
   - `council-devil-advocate`
   - `council-perf-skeptic`
   - `council-ux-critic`
5. Pass each member the diff, change description, trigger, active plan,
   relevant ADRs, and `lessons.md`.
6. Collect all five verdicts. Apply must-fix conditions inline.
7. Write `.codex/council-logs/<YYYY-MM-DD>-<slug>.md` with verdicts,
   conditions met before commit, deferred risks, file changes, and next
   action.
8. Surface a summary table to the user.

Stop after step 8. Do not auto-commit on behalf of the council.

If `$ARGUMENTS` is non-empty, treat it as additional context.
