# Future work (v2 and beyond)

Items deliberately deferred from the v1 scope (per
[process/implementation-plan.md](../process/implementation-plan.md)
"Out of scope"), plus enhancement ideas picked up during v1
implementation. Not a promise — anything here needs a standalone design
pass before it ships.

For audit-driven post-v1 work that **is** scheduled (phases 10–14), see
[process/implementation-plan.md](../process/implementation-plan.md) and
[explain/risks.md](risks.md).

## Deferred from v1

- **Sandboxed-app preference sync** (FDA-gated). Requires
  `com.apple.security.files.all` entitlement and a per-app
  quit-relaunch dance. See
  [reference/preference-sync.md](../reference/preference-sync.md) and
  [reference/pref-domains.md](../reference/pref-domains.md).
- **Concurrent-write merge** for multi-user Macs. Current v1 assumes
  one active writer at a time via `.sojourn/active.toml`. See
  [decisions/0012-cooperative-writer-lock.md](../decisions/0012-cooperative-writer-lock.md).
- **SwiftTerm-embedded console pane.** Current v1 uses `LogConsoleView`
  with `ANSIParser`-rendered `AttributedString`. Full terminal emulation
  (cursor control, resize) is SwiftTerm territory.
- **`SMAppService.agent`** replacement for `NSBackgroundActivityScheduler`.
  Cleaner lifecycle for macOS 13+ but requires a helper bundle; Phase 4
  uses the simpler API.
- **Mac App Store submission.** Requires full sandbox — breaks the
  subprocess model that is Sojourn's core design.
- **Non-macOS platforms.** Decided in
  [decisions/0014-no-linux-no-helling-plugin.md](../decisions/0014-no-linux-no-helling-plugin.md).
- **Hosted backend.** Sojourn is local-only. A hypothetical multi-user
  SaaS would require AGPL-3.0 licensing for that server component.

## Enhancements surfaced during v1 work

- **Sparkle auto-updater** for the `.app`. Add alongside the Homebrew
  cask path so non-Homebrew users still get signed updates.
- **HistoryEntry** — show diff + linked git SHA for revert UX (v1
  records the entry but not yet the SHA).
- **Per-file dry-run preview** default-on in Settings. Surfaces in
  [reference/sync-model.md](../reference/sync-model.md); make it the
  Settings default.
- **Linux-home sync via age-encrypted tarballs** — interesting v2
  direction; would need a full cross-platform reshape (and reverses
  ADR-0014). Tracked here as a hypothetical, not a roadmap item.
- **Hardware key (Yubikey) for commit signing** via `ssh-keygen -Y`
  on Sonoma 14.0+. See
  [reference/ssh-config.md](../reference/ssh-config.md) "SSH commit
  signing".

## Audit-promoted (now scheduled in implementation-plan)

The following items were "future" in v0.1 and are now scheduled:

- **Plugin system for custom service actors** — phase 14, ADR-0013.
- **OSLog + `os_signpost` instrumentation** — phase 11, partial in
  [explain/observability.md](../explain/observability.md).
- **OBSERVABILITY doc** — shipped at
  [explain/observability.md](../explain/observability.md).
- **THREAT_MODEL doc** — phase 8 of docs rework (lands at
  `docs/explain/threat-model.md`).
- **ADR log** — shipped at [decisions/](../decisions/).
- **`pnpm` support** — plugin protocol target, see
  [reference/package-managers/pnpm.md](../reference/package-managers/pnpm.md).
