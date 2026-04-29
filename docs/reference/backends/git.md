# git — shell out to `/usr/bin/git`

No SwiftGit2, no SwiftGitX, no libgit2. System `git` always exists on macOS
(the `/usr/bin/git` shim triggers Xcode CLT install if missing, which
Sojourn's bootstrap handles explicitly anyway). This is what GitHub Desktop,
Fork, Tower, Sourcetree, Sublime Merge all do. See
[decisions/0007-shell-out-to-git.md](../../decisions/0007-shell-out-to-git.md).

## Reasons (ranked)

1. Dotfile repos are tiny. No libgit2 perf advantage.
2. User's `.gitconfig` probably has commit signing, credentials, SSH agent,
   LFS — shelling out respects all of it for free. `git-credential-osxkeychain`
   is default on macOS and handles Keychain auth without Sojourn writing a
   single line.
3. No notarization burden of bundling libgit2 + OpenSSL + libssh2.
4. libgit2 lacks Git LFS, SSH agent forwarding; SSH signing support is
   partial.

## Porcelain flags used

- `git status --porcelain=v2 --branch -z`
- `git log --pretty=format:'%H%x00%an%x00%at%x00%s' -z`
- `git diff --numstat -z`

Null-terminated. Safer than newline-split.

## Authentication

Both OAuth Device Flow (for GitHub new users) and BYO remote (the default,
works for any host). See [reference/sync-model.md](../sync-model.md)
"Authentication" for detail.
