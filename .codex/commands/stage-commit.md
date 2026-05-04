---
description: Pre-flight a v0.X stage commit (gitleaks + build + test + review) and bump CURRENT_PROJECT_VERSION.
---

Pre-flight a stage commit for the active v0.X plan. This command catches
the common checks Sojourn requires before landing on `main`.

Steps:

1. Confirm the working tree has changes: `git status --short`. Abort
   with explanation if nothing should be committed.
2. Identify the current stage from `docs/process/plans/v0.X-plan.md`
   and recent commits matching `vX.Y stage N:`. Increment the build
   number for this stage in `project.yml`.
3. Run pre-commit checks:
   - `gitleaks dir --config=.gitleaks.toml --redact --no-banner`
   - `swift build`
   - `xcodebuild test -project Sojourn.xcodeproj -scheme Sojourn
     -destination 'platform=macOS,arch=arm64' -only-testing:SojournTests`
4. If any check fails: surface the failure, do not commit, and fix the
   blocker first.
5. Determine whether council fires from `AGENTS.md`. If yes, spawn the
   five `council-*` subagents in parallel and write the deliberation log
   under `.codex/council-logs/` before continuing. If no, spawn
   `self-critique` on the diff and apply any FIX-FIRST findings.
6. Update `CHANGELOG.md` `[0.X.0] - unreleased` section with one bullet
   per affected file group.
7. Stage explicit files only. Never use `git add -A`.
8. Draft the commit message using the existing pattern:
   ```
   v0.X stage N: <one-line summary>

   - <bullet>
   - <bullet>
   ```
   Use `git commit -s`. Never pass `--no-verify`.
9. After commit lands, mark the stage complete and move to the next
   stage.

If `$ARGUMENTS` is non-empty, use it as the commit-message subject
override.
