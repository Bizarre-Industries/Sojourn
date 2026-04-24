# Future work (v2 and beyond)

Items deliberately deferred from the v1 scope
([IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) "Out of scope"), plus
enhancement ideas picked up during v1 implementation. Not a promise —
anything here needs a standalone design pass before it ships.

## Deferred from v1

- **Sandboxed-app preference sync** (FDA-gated). Requires
  `com.apple.security.files.all` entitlement and a per-app
  quit-relaunch dance. See [ARCHITECTURE.md](ARCHITECTURE.md) §15 and
  [PREFS_DOMAINS.md](PREFS_DOMAINS.md).
- **Concurrent-write merge** for multi-user Macs. Current v1 assumes
  one active writer at a time via `.sojourn/active.toml`.
- **`pnpm` support.** See [SUPPORTED_MANAGERS.md](SUPPORTED_MANAGERS.md);
  needs a parallel `PnpmService` since mpm does not cover it.
- **SwiftTerm-embedded console pane.** Current v1 uses `LogConsoleView`
  with `ANSIParser`-rendered `AttributedString`. Full terminal emulation
  (cursor control, resize) is SwiftTerm territory.
- **`SMAppService.agent`** replacement for `NSBackgroundActivityScheduler`.
  Cleaner lifecycle for macOS 13+ but requires a helper bundle; Phase 4
  uses the simpler API.
- **Mac App Store submission.** Requires full sandbox — breaks the
  subprocess model that is Sojourn's core design.
- **Non-macOS platforms.** SwiftUI / Foundation would build, but
  Homebrew + `defaults` + LaunchServices are macOS-only.
- **Hosted backend.** Sojourn is local-only. A hypothetical multi-user
  SaaS would require AGPL-3.0 licensing for that server component.

## Enhancements surfaced during v1 work

- **Sparkle auto-updater** for the `.app`. Add alongside the Homebrew
  cask path so non-Homebrew users still get signed updates.
- **OSLog + `os_signpost` instrumentation** across `SubprocessRunner`
  and `SyncCoordinator`. Ties into §18 Observability.
- **HistoryEntry** — show diff + linked git SHA for revert UX (v1
  records the entry but not yet the SHA).
- **Per-file dry-run preview** default-on in Settings. Surfaces in
  ARCHITECTURE.md §6; make it the Settings default.
- **Plugin system for custom service actors** — allow users to drop a
  Swift Package in `~/Library/Application Support/Sojourn/plugins/`
  and have Sojourn load it for a custom package manager.
- **Linux-home sync via age-encrypted tarballs** — interesting v2
  direction; would need a full cross-platform reshape.
- **Hardware key (Yubikey) for commit signing** via `ssh-keygen -Y`
  on Sonoma 14.0+.

## Nice-to-have docs

- `docs/OBSERVABILITY.md` once OSLog signposts are instrumented.
- `docs/THREAT_MODEL.md` with ASCII/mermaid diagram — partial today in
  `docs/SECURITY.md`.
- A `docs/DECISIONS/` ADR log, timestamped, capturing the actual design
  debates (IPC-not-linking, no-symlink-preferences, cooldown tiers).
