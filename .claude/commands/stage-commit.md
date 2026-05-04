---
description: Pre-flight a v0.X stage commit (gitleaks + build + test + self-critique) and bump CURRENT_PROJECT_VERSION.
---

Pre-flight a stage commit for the active v0.X plan. Catches the
common pre-commit checks Sojourn requires before landing on `main`.

Steps:

1. Confirm the working tree has changes: `git status --short`. Abort
   with explanation if nothing to commit.
2. Identify the current stage from `docs/process/plans/v0.X-plan.md`
   (look for `[in_progress]` in the local TodoWrite list, or scan
   recent commits for `vX.Y stage N:` prefix). Increment the build
   number for this stage in `project.yml`
   (`CURRENT_PROJECT_VERSION: N` → `N+1`).
3. Run pre-commit checks in parallel:
   - `gitleaks dir . --no-banner` — must pass.
   - `swift build` — must be clean (zero warnings).
   - `xcodebuild test -scheme Sojourn -destination 'platform=macOS,arch=arm64' -only-testing:SojournTests`
     — must pass.
4. If any check fails: surface the failure, do NOT commit, propose
   the fix.
5. Determine whether council fires (per CLAUDE.md trigger list). If
   yes → invoke `/council` and wait for the deliberation log before
   continuing. If no → spawn the `self-critique` subagent on the
   diff and apply any FIX-FIRST findings.
6. Update `CHANGELOG.md` `[0.X.0] — unreleased` section with one
   bullet per affected file group.
7. Stage all relevant files (do NOT use `git add -A` — list explicit
   paths to avoid accidentally committing build artifacts or .env
   files).
8. Draft the commit message using the existing pattern:
   ```
   v0.X stage N: <one-line summary>

   - <bullet>
   - <bullet>
   ```
   Use `git commit -s -m "$(cat <<'EOF' ... EOF)"` HEREDOC form.
   Never `--no-verify`. Never include `Co-Authored-By: Claude`.
9. After commit lands, mark the stage `[completed]` in TodoWrite +
   move to next stage.

If `$ARGUMENTS` is non-empty, use it as the commit-message subject
override.
