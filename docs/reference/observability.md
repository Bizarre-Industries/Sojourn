# Observability

Logging is OSLog-first. Audit
[process/audit-2026-04.md §5.2.6](../process/audit-2026-04.md#52-missing-docs)
flagged a need for a dedicated observability doc; this is it.

## Categories

Each service declares:

```swift
private static let log = Logger(
    subsystem: "app.bizarre.sojourn",
    category: "<name>"
)
```

Categories: `sync`, `subprocess`, `bootstrap`, `secrets`, `cleanup`, `ui`.

## Levels

| Level | Use |
|---|---|
| `.debug` | High-volume pipe chatter |
| `.info` | Job start/end |
| `.error` | Recoverable failures |
| `.fault` | Invariant breaks (also triggers user-visible alert) |

## User-exportable bundle

Settings → Security tab offers "Export diagnostics bundle" which writes
`AppSupportPaths.logs/<ts>.json` with:

- The last 24h of OSLog entries.
- `AppStore.history`.
- Tool inventory (`ToolLocator` results).
- chezmoi doctor output (per audit §2.2.7 / §4.1.6 — embed when available).

Redacted via gitleaks-like patterns before write. The export bundle is the
canonical artifact users attach to bug reports.

## Signposts

`os_signpost` regions wrap:

- `SyncCoordinator.pull`
- `SyncCoordinator.push`
- `MPMService.outdated` per manager
- `ChezmoiService.apply`
- `BootstrapService` per state

Instruments can show per-phase wall-clock cost. Ties into audit
[process/audit-2026-04.md §3.1.5](../process/audit-2026-04.md#3-architectural-gaps)
which proposes a `Diagnostics/` module to centralize these.

## Crash reports

Stay local (macOS submits to Apple; Sojourn never collects them).

## Retention

OSLog is Apple-managed; we do not explicitly rotate. Diagnostics bundles
under `AppSupportPaths.logs/` inherit the 30-day GC policy that
`BackupsDirectory` uses for snapshots.

## Per-job log capture

Independent of OSLog. `JobRunner` owns a per-`Job` `LogBuffer` (ring buffer,
~5 MB cap) for the embedded log pane. The user can copy/save this directly.
See [reference/modules.md](modules.md) "Streaming output".
