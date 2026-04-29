# 0014 — No Linux platform; Sojourn does not become a Helling plugin

- **Status**: Proposed (boundary decision; future maintainers may revisit)
- **Date**: 2026-04-28
- **Deciders**: Sojourn maintainer

## Context

Two questions periodically resurface:

1. Should Sojourn ship a Linux build? SwiftUI / Foundation would build,
   but the differentiating subsystems (Homebrew, `defaults`, cfprefsd,
   LaunchServices, signed-`.pkg` bootstrap) are macOS-only.
2. Should Sojourn become a plugin under Helling
   (`Bizarre-Industries/Helling`) — the maintainer's other indie OSS
   project — to inherit a plugin host?

The audit
[process/audit-2026-04.md §7 "Don't do"](../process/audit-2026-04.md#dont-do)
explicitly rejects both. Documenting the decision so future maintainers
tempted to pivot have the context.

## Decision

Sojourn is **macOS-native only**. It does not target Linux, Windows, or
mobile. It does not become a Helling plugin.

The 80% of value Sojourn delivers is macOS-specific: the Mackup-derived
applications registry, plist round-tripping through `cfprefsd`, the
signed-`.pkg` bootstrap, LaunchAgents, Login Items via `SMAppService`.
A Sojourn-on-Linux project would be a different product with different
trade-offs and a different architecture.

The Helling plugin path strips the macOS-native UX (`MenuBarExtra`,
`NSBackgroundActivityScheduler`, `SwiftUI` `NavigationSplitView`,
Authorization sheets) which is exactly the differentiator vs `nix-darwin`,
`chezmoi` alone, or Mackup.

## Consequences

### Positive

- Engineering focus stays on macOS-specific UX wins.
- No cross-platform abstraction tax in code or docs.
- Helling stays free to evolve as a Linux/server tool without dragging
  Sojourn's macOS dependencies.

### Negative

- Linux developers asking for Sojourn get a "not a fit, look at chezmoi
  + asdf manually" answer. Acknowledged.

### Neutral

- The plugin protocol from
  [0013-out-of-process-plugins.md](0013-out-of-process-plugins.md) is
  Sojourn-specific, not Helling-compatible. If a future Sojourn-on-Linux
  project starts, plugin compat would be a fresh design call.

## Alternatives considered

- **Linux build using SwiftUI + portable backends** — rejected. The
  portable subset is not where Sojourn's value lives.
- **Sojourn-as-Helling-plugin** — rejected. Strips macOS-native UX.
- **Cross-platform "core" + macOS-specific UI shell** — considered but
  rejected. The "core" is small (mpm/chezmoi/git wrappers, all already
  cross-platform). The UI shell is where 70% of the work is. Splitting
  doesn't yield reuse worth the complexity.
