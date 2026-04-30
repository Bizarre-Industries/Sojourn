# pnpm

Fast, disk-efficient Node.js package manager. **Not supported by mpm**;
deferred to v2 per the audit.

Plugin protocol target — see
[../plugin-protocol.md](../plugin-protocol.md). A community-maintained
`pnpm.sojourn-plugin` is the most likely path.

## Tier

**E** (would be) — same gating as npm. Lifecycle scripts run.

## Binary

`~/.pnpm/bin/pnpm` or via `corepack` (`~/.config/corepack/`).

## Status

Until a pnpm plugin ships, users with pnpm installed should sync
`~/.pnpmfile.cjs` and `~/.npmrc` as plain dotfiles via chezmoi. The
list of globally-installed pnpm packages is not auto-captured.

Tracked in [explain/future-work.md](../../explain/future-work.md).
