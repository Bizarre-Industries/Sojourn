# 0007 — Shell out to `/usr/bin/git`; do not link libgit2

- **Status**: Accepted
- **Date**: 2026-04-24
- **Deciders**: Sojourn maintainer

## Context

Sojourn needs git operations: clone, fetch, status, diff, commit, push,
pull. Two paths:

1. Link `libgit2` (or its Swift wrapper `SwiftGit2` / `SwiftGitX`).
2. Shell out to the system `/usr/bin/git`.

`/usr/bin/git` always exists on macOS; the shim triggers Xcode CLT install
if missing. GitHub Desktop, Fork, Tower, Sourcetree, Sublime Merge all
shell out — there's a strong precedent for this on macOS.

## Decision

Sojourn shells out to `/usr/bin/git` via `GitService` (an actor wrapping
`SubprocessRunner`). No `libgit2`, no `SwiftGit2` / `SwiftGitX`, no
`ObjectiveGit`.

Porcelain flags: `git status --porcelain=v2 --branch -z`,
`git log --pretty=format:'%H%x00%an%x00%at%x00%s' -z`,
`git diff --numstat -z`. Null-terminated; safer than newline-split.

## Consequences

### Positive

- The user's `.gitconfig` is honored automatically: commit signing,
  credentials, SSH agent, LFS, hooks. `git-credential-osxkeychain` is
  default on macOS — Keychain auth works without Sojourn writing a line.
- No notarization burden of bundling libgit2 + OpenSSL + libssh2.
- libgit2 lacks Git LFS, has partial SSH agent forwarding, partial SSH
  signing — shelling out gets all of these for free.
- Bootstrap already triggers Xcode CLT install when missing (see
  [explain/bootstrap-state-machine.md](../explain/bootstrap-state-machine.md)).

### Negative

- Subprocess overhead per git call (typically <30ms; not a bottleneck).
- Output parsing is fragile if porcelain format changes (unlikely;
  `--porcelain=v2` is stable contract).

### Neutral

- Dotfile repos are tiny. No libgit2 perf advantage even if linked.

## Alternatives considered

- **`SwiftGit2`** — rejected. Maintenance unclear; libgit2 limitations
  apply.
- **`SwiftGitX`** — rejected. Same as SwiftGit2.
- **Apple's `Foundation.Process` directly without a wrapper** — partially
  adopted; `GitService` uses `SubprocessRunner` which wraps either
  `swift-subprocess` or raw `Process` per
  [reference/modules.md](../reference/modules.md).
