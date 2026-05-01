# Council deliberation — notarize.yml publish step rewrite

**Date**: 2026-05-01
**Trigger**: change to `.github/workflows/notarize.yml` (CLAUDE.md trigger 5).
**Context**: User asked to make the cask bump "update on main and not open a PR". The previous "Publish Homebrew cask update" step at lines 154-168 invokes `brew bump-cask-pr --no-fork`, which always opens a PR.

## Original proposal

Replace `brew bump-cask-pr` with a 30-line direct-push script:

- `git clone` the tap with `https://x-access-token:${TAP_TOKEN}@github.com/...`
- `sed` edit the `version` and `sha256` lines
- `brew style` the result
- `git commit -s` as `github-actions[bot]`
- `git push origin main`

## Council vote

| Member         | Decision                  |
|----------------|---------------------------|
| architect      | APPROVE-WITH-CONDITIONS   |
| security       | REJECT                    |
| devil-advocate | REJECT                    |
| ux-critic      | APPROVE-WITH-CONDITIONS   |
| perf-skeptic   | APPROVE                   |

## Reject rationale (security)

- **Token leak**: `https://x-access-token:${TAP_TOKEN}@github.com/...` persists in `${tap_dir}/.git/config` for the lifetime of the job. Same-job steps can read it. "Ephemeral runner" is not a security boundary.
- **Lost audit gate**: `brew bump-cask-pr` invokes `brew audit --strict` against the bumped tap-side cask, which downloads the asset from the GitHub release URL and verifies the sha matches. The proposed script computes sha locally from the in-runner `Sojourn.dmg` — if upload corrupted the asset, the cask publishes a sha that doesn't match what users download.
- **Shell injection**: `${GITHUB_REF_NAME}` is interpolated directly into `sed -E`. A maliciously crafted tag breaks the substitution and could execute arbitrary commands.
- **No GPG sign**: only `-s` (DCO sign-off, metadata only). No cryptographic signature on the commit.
- **Single-factor compromise**: tag-push is the only authentication factor for shipping a cask to every Homebrew user.

## Reject rationale (devil-advocate)

- Replacing 6 lines of upstream-maintained `brew bump-cask-pr` invocation with 30 lines of hand-rolled shell violates "smallest diff that solves the problem" (CLAUDE.md user rules).
- Sed regex assumes single-line `version "x.y.z"` form. Future cask DSL changes (multi-line `version do…end`, `version :latest`, `arch` stanzas) will silently corrupt the file. `bump-cask-pr` uses Ruby AST-aware edits and is updated in lockstep with the DSL.
- Lost PR audit trail (commit attribution, CI checks, reviewable diff) on the most security-sensitive workflow in the repo.
- Online audit runtime is overstated: ~30-60s for DMG download + audit on GHA runners; notarization itself takes 5-15 minutes. Trading the audit for ~25s saved is a bad bet.
- **Recommended alternative**: keep `brew bump-cask-pr --no-fork` (no fork, PR opens directly on tap) and add `gh pr merge --squash --delete-branch <url>` immediately after. Net: 1 line added, 0 lines of upstream code removed. Single commit on main, full audit retained.

## Approve-with-conditions rationale

### Architect
- Confirm `${{ env.HOMEBREW_TAP_TOKEN }}` mapping is set at job-env level (otherwise empty token fails silently).
- Add post-substitution assertion that version + sha256 actually changed.
- Confirm appcast publication path is unaffected (ADR-0020 hybrid model).
- Append lessons.md entry documenting the trade-off.

### UX-critic
- Commit message must include `release-url` and `workflow-run` lines so reader can navigate from tap commit log back to source.
- Post-sed verification step must `grep -q "version \"${version}\"" Casks/sojourn.rb` and assert sha format `[a-f0-9]{64}`.
- Push must be non-force; branch protection rejection should surface as a clear error.

### Perf-skeptic
- ~30x speedup (5-8 min → 10-15s) for the slowest serial step.
- `brew style` must run against the post-sed file in the tmp clone, not the pre-bump source.
- Add 30s timeout on `git push` to fail fast on auth hangs.

## Decision

**Adopt the devil-advocate hybrid**: `brew bump-cask-pr --no-fork` followed by `gh pr merge --squash --delete-branch`.

Rationale:
- Resolves every security concern: no token in `.git/config` (gh handles auth via env), `bump-cask-pr` keeps the online sha verification + AST-aware edit, `--no-fork` keeps PR scope minimal.
- Resolves devil-advocate's brittleness concern by keeping upstream tooling.
- Meets user's "update on main, not a PR" intent — the PR is briefly opened by `bump-cask-pr` then immediately squash-merged. End state on tap: single commit on main, no lingering PR. Reader of `git log main` sees the same history as a pure direct-push.
- Resolves architect's appcast concern (out of scope here — appcast is part of v0.3 plan, not yet implemented).
- Resolves ux-critic's audit-trail concern: PR (even if instantly merged) leaves a number, checks record, and `gh pr view` history.
- Adds tag-format validation (`^[0-9]+\.[0-9]+\.[0-9]+$`) before any substitution to address security concern #3 even though the hybrid path doesn't shell-interpolate the version into sed.

## Action items

1. Implement hybrid in `.github/workflows/notarize.yml` (next commit).
2. Append entry to `lessons.md` under "Homebrew cask publishing" documenting why we did NOT go with custom direct-push.
3. (Optional, future) When v0.3 ships the appcast, extend this step to bump it too.

## References

- `.github/workflows/notarize.yml:154-168` — current publish step
- `docs/decisions/0020-sparkle-plus-cask-hybrid-update.md` — tap-as-runtime-source design
- `CLAUDE.md` — council trigger rules + "smallest diff" + "shell out to mature tools" guidance
- `lessons.md` — pending append
