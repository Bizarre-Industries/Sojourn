# 0008 — Install Homebrew via signed `.pkg`, not `curl | bash`

- **Status**: Accepted
- **Date**: 2026-04-24
- **Deciders**: Sojourn maintainer

## Context

Sojourn's bootstrap flow installs Homebrew on first run when absent. The
official Homebrew install snippet is `curl | bash`, with a
`NONINTERACTIVE=1` flag to skip the Y/N prompt. Even with that flag, the
script invokes `sudo` — which is a dead end for a GUI that has no terminal
session and cannot cache a sudo ticket.

Homebrew also ships a signed `.pkg` installer per release with a stable
Apple Developer ID Team ID. macOS's `/usr/sbin/installer` accepts a
`.pkg` and prompts for Authorization once natively.

## Decision

Bootstrap installs Homebrew via the signed `.pkg`:

1. Resolve the latest release via `gh api repos/Homebrew/brew/releases/latest`.
2. Download the `.pkg` asset.
3. Verify Apple signature with `pkgutil --check-signature`; assert Team ID.
4. Hand off to `/usr/sbin/installer` (or `open -W`). User sees one native
   Authorization dialog.
5. Post-install verify: `/opt/homebrew/bin/brew --version` (Apple Silicon)
   or `/usr/local/bin/brew --version` (Intel).

## Consequences

### Positive

- One native Authorization dialog. Clean. No terminal.
- Apple signature verification before install — supply-chain protection.
- Works in a GUI context where `sudo` has no session.

### Negative

- Tied to Homebrew's release cadence for `.pkg` artifacts.
- If the upstream Team ID rotates, we have to update the assertion.

### Neutral

- The signed-`.pkg` approach matches what `Cork`, `Applite`, and
  `Pearcleaner` do for the same reasons.

## Alternatives considered

- **`NONINTERACTIVE=1 curl | bash`** — rejected. Still calls `sudo`; GUI
  can't cache a ticket.
- **Bundle Homebrew inside the app** — rejected per
  [0009-bundle-binary-policy.md](0009-bundle-binary-policy.md). Brew
  refuses non-default prefixes and self-updates aggressively.
- **Skip Homebrew entirely; install mpm/chezmoi via direct binary
  download** — fallback path only. Brew is the dominant macOS package
  manager and the user's Sojourn-managed packages will mostly live in it.
