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

---

## RE-VOTE — same day, after CI evidence

**Trigger for re-vote:** v0.2.5 CI run 25224297831 ran the hybrid this
council approved. bump-cask-pr did the cask edit, commit, and branch
push successfully — but its PR-creation API call exited with `Your
HOMEBREW_GITHUB_API_TOKEN credentials do not have sufficient scope!
Scopes required: repo. Scopes present: none.` Local probe of `gh pr
create` with the same PAT confirmed: `GraphQL: Resource not accessible
by personal access token (createPullRequest)`.

Root cause: HOMEBREW_TAP_TOKEN is a fine-grained PAT with `Contents:
Read and write` (branch push works) but lacks `Pull requests: Read and
write`. bump-cask-pr's legacy classic-PAT scope check sees fine-grained
PATs as "no scopes".

User decision: rather than ask the user to add Pull requests: write to
the PAT (would unblock the hybrid), switch to direct-push.

**Re-vote tally:**

| Member         | Original                | Re-vote                  |
|----------------|-------------------------|--------------------------|
| architect      | APPROVE-WITH-CONDITIONS | APPROVE-WITH-CONDITIONS  |
| security       | REJECT                  | APPROVE-WITH-CONDITIONS  |
| devil-advocate | REJECT                  | APPROVE-WITH-CONDITIONS  |
| ux-critic      | APPROVE-WITH-CONDITIONS | APPROVE                  |
| perf-skeptic   | APPROVE                 | APPROVE-WITH-CONDITIONS  |

5/5 approve direct-push given the new evidence + safeguards.

## Re-vote rationale highlights

**Security flipped REJECT → APPROVE-WITH-CONDITIONS:**
- Token scrub via `git remote set-url origin <no-token>` post-clone +
  ephemeral `-c http.extraheader` on the push closes the `.git/config`
  leak.
- `brew audit --cask --online` after the edit restores the upload-corruption
  detection.
- Tag-format guard closes the shell-injection vector.
- Conditions: `::add-mask::` on the token, post-edit assertions (positive
  AND negative grep), TODO comment for self-hosted runner migration.

**Devil-advocate flipped REJECT → APPROVE-WITH-CONDITIONS:**
- Maintained the engineering preference for option (a) — adding Pull
  requests: write to the PAT — but conceded the user has firmly chosen
  (b).
- Required: local `brew style` + `brew audit --strict --online` before
  push, fail-closed; sha computed from notarized DMG only (not re-fetched);
  no force-push; livecheck-stanza check.

**Architect APPROVE-WITH-CONDITIONS unchanged:**
- Don't swallow `brew tap-new` failures with `|| true`.
- `mkdir -p Casks/` before the `cp` to handle tap-layout drift.
- Verify push landed via `git ls-remote origin main`.

**UX-critic upgraded APPROVE-WITH-CONDITIONS → APPROVE:**
- Commit-message format already meets the previous conditions
  (release-url, workflow-run, sha256). No new concerns from removing the
  PR.

**Perf-skeptic APPROVE-WITH-CONDITIONS:**
- `brew audit --cask` adds 30-60s, total ~45-75s (still ~5x faster than
  bump-cask-pr's 5-8 min).
- Conditions: `timeout 180` on `brew audit`, `timeout 30` on `git push`.

## Implemented safeguards (mapped to conditions)

In the rewritten `Publish Homebrew cask update` step:

| Council condition                                               | Implementation                                                                       |
|------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| Tag-format guard before any interpolation                        | `[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]` line ~25                            |
| `::add-mask::` on token                                          | `echo "::add-mask::${TAP_TOKEN}"` line ~22                                            |
| Token scrub post-clone                                           | `git remote set-url origin https://github.com/...` (no token)                         |
| Ephemeral push token (argv only)                                 | `git -c "http.https://github.com/.extraheader=AUTHORIZATION: bearer ${TAP_TOKEN}" push` |
| Post-edit positive grep (version + sha)                          | Two `grep -q` blocks with `exit 1` on miss                                            |
| Post-edit negative grep (old version + sha absent)               | Two more `grep -q` blocks comparing `${old_version}` / `${old_sha}`                   |
| Online audit on bumped cask                                      | `brew tap … && cp … && brew audit --cask --online sojourn`                            |
| Audit timeout                                                    | `timeout 180 brew audit`                                                              |
| Push timeout                                                     | `timeout 30 git push`                                                                 |
| Push-landed verification                                         | `git ls-remote origin refs/heads/main` compared against local HEAD                    |
| Self-hosted runner caveat                                        | TODO comment at top of step                                                           |
| Lessons.md entry                                                 | Appended above the original entry                                                     |
| Follow-up: revisit at v0.3 PAT rotation                          | GitHub issue (next action)                                                            |
