# Bootstrap flow

First-run experience for Sojourn. Owned by `BootstrapService`. See
[decisions/0008-no-curl-bash-for-brew.md](../decisions/0008-no-curl-bash-for-brew.md)
for the install model, and
[explain/bootstrap-state-machine.md](../explain/bootstrap-state-machine.md)
for the rationale on Authorization sheets.

## State machine

```
.unknown
  → .probingSystem        // parallel: locate brew/git/mpm/chezmoi/age/gitleaks + xcode-select -p
  → .reportingStatus      // show inventory to user
  → .awaitingUserConsent  // single "Install missing" sheet
  → .installingCLT        // xcode-select --install; observe until done
  → .installingBrew       // signed .pkg installer via /usr/sbin/installer
  → .installingMpm        // brew install meta-package-manager
  → .installingChezmoi    // brew install chezmoi
  → .ready
  → .failed(Error)        // per-step retry/skip UI
```

## Detection

App-context `PATH` is LaunchServices-minimal. `which(1)` fails for brew on
Apple Silicon. Use `ToolLocator.candidatePaths` — the hardcoded list in
[Sojourn/Services/ToolLocator.swift](../../Sojourn/Services/ToolLocator.swift).
First hit wins. Cache in `Settings.toolLocations`.

Hardcoded candidates: `/opt/homebrew/bin/brew`, `/usr/local/bin/brew`,
`~/.cargo/bin`, `~/.local/bin`, `~/go/bin`, `/usr/bin`.

Xcode Command Line Tools: `xcode-select -p` exit code 0 means installed.
Non-zero triggers `xcode-select --install`, which opens Apple's system
sheet. Poll `xcode-select -p` every 5s until it succeeds or the user
cancels.

## Homebrew install

Do **not** use `curl | bash`. Even with `NONINTERACTIVE=1`, it still invokes
`sudo`, which is a dead-end for a GUI that can't cache a sudo ticket.

Flow:

1. Resolve latest Homebrew release via `gh api repos/Homebrew/brew/releases/latest`.
2. Download the signed `.pkg` asset.
3. Verify Apple signature: `pkgutil --check-signature Homebrew-*.pkg`;
   assert Team ID matches the documented Homebrew Developer ID.
4. Hand off to `/usr/sbin/installer`: user gets one native Authorization
   dialog.
5. Post-install verify: `/opt/homebrew/bin/brew --version` on Apple Silicon,
   `/usr/local/bin/brew --version` on Intel.

## mpm install

Prefer `brew install meta-package-manager`. Fallback if brew fails or is
skipped:

1. Download the Nuitka-compiled standalone binary for the host arch from the
   mpm releases page via `gh release download`.
2. Verify SHA-256 against the checksum file in the same release.
3. Remove the quarantine xattr: `xattr -d com.apple.quarantine /path/to/mpm`.
4. Install to `~/Library/Application Support/Sojourn/bin/mpm`. Add that to
   the `Settings.toolLocations` cache.

Do not bundle mpm inside `Contents/Resources/`. See
[reference/backends/mpm.md](backends/mpm.md) and
[decisions/0009-bundle-binary-policy.md](../decisions/0009-bundle-binary-policy.md).

## chezmoi install

Prefer `brew install chezmoi`. Fallback: direct binary from chezmoi's
release page (signed + notarized as of 2024+). Do not use the
`get.chezmoi.io` pipe-to-shell path from a GUI context for the same reason
as brew.

Configure `merge.command` in `~/.config/chezmoi/chezmoi.toml` during
bootstrap so future `chezmoi merge` calls have a default (e.g., `opendiff`,
FileMerge, `kdiff3`). Per audit §6.5.

## gitleaks + age

Bundled inside the app at `Contents/Resources/bin/`. Re-signed and notarized
as part of Sojourn. No bootstrap step.

## Secondary managers

On-demand. First time the user asks Sojourn to sync an `npm` / `pip` /
`cargo` / `gem`-tracked package, offer `brew install <manager-backend>` in
a sheet. Installing them all upfront wastes 1–2 GB for users who won't
touch that ecosystem.

## UX rules

- Only three steps require foreground user action: the initial consent
  sheet, the CLT installer dialog, the brew `.pkg` Authorization prompt.
- Everything else streams stdout into the Bootstrap view's log pane.
- The menu bar icon remains active; the user can minimize to menu bar and
  come back when the log shows `.ready`.
- Any `.failed(Error)` state offers Retry, Skip, and Open Documentation.
