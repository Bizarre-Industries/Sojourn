# Future work (v2 and beyond)

Items deliberately deferred from the v1 scope (per
[process/implementation-plan.md](../process/implementation-plan.md)
"Out of scope"), plus enhancement ideas picked up during v1
implementation. Not a promise — anything here needs a standalone design
pass before it ships.

For audit-driven post-v1 work that **is** scheduled (phases 10–14), see
[process/implementation-plan.md](../process/implementation-plan.md) and
[explain/risks.md](../explain/risks.md).

## Deferred from v1

- **Sandboxed-app preference sync** (FDA-gated). Requires
  `com.apple.security.files.all` entitlement and a per-app
  quit-relaunch dance. See
  [reference/preferences.md](../reference/preferences.md) and
  [reference/preferences.md](../reference/preferences.md).
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

## Audit-deferred — L-severity items not yet scheduled

These are [process/audit-2026-04.md](audit-2026-04.md) items the audit
flagged as L (low value or niche) and that are not on the
implementation-plan ladder. They live here to keep the audit's
deferral decisions traceable without bloating the active plan.

| Audit ID | Item | Decision |
|---|---|---|
| 2.1.4 | `mpm cleanup` cache prune | Wire opportunistically alongside §2.1.3 daily refresh; otherwise defer. |
| 2.1.6 | Per-project `[tool.mpm]` in `pyproject.toml` | v1.1+; needs Machines pane UI surface. |
| 2.1.7 | TOML output for `outdated` snapshots | Cosmetic; cleaner git diffs. |
| 2.1.8 | `cpan`, `steamcmd` manager coverage | Rare audience; keep on watchlist. |
| 2.2.10 | `.chezmoitemplates/` partials | Wire when generated per-machine override blocks duplicate. |
| 2.2.11 | `chezmoi edit --watch` | Power-user; users invoke directly. |
| 2.2.12 | `encrypted_` + `.tmpl` combination | Niche; add when a user actually asks. |
| 2.4.5 | `duti` default-app capture | If `duti` installed; otherwise out of scope. |
| 2.4.7 | LaunchServices DB binding capture | v2; needs `lsregister`-aware tooling. |
| 2.4.9 | crontab | Redirected to launchd; not synced. |
| 2.5.5 | `~/.ssh/authorized_keys` | Out of scope on the dev's own Mac. |
| 2.6.4 | `onepassword.mode` trade-off doc | Phase 14 wiring optional. |
