# Architecture

Sojourn's high-level component diagram and the layering rules every PR must
respect. For per-subsystem detail see [reference/modules.md](modules.md);
for backend integration see [reference/backends/](backends/).

## Diagram

```mermaid
flowchart LR
  UI[SwiftUI UI Layer<br/>3-pane window + MenuBarExtra] --> Store[AppStore<br/>@Observable root]
  Store --> Jobs[JobRunner<br/>async Tasks + LogBuffer]
  Jobs --> Services
  subgraph Services[Service actors]
    BrewSvc[BrewService]
    MPMSvc[MPMService]
    ChezSvc[ChezmoiService]
    GitSvc[GitService]
    PrefSvc[PrefService]
    ScanSvc[SecretScanService]
    BootSvc[BootstrapService]
    SchedSvc[SchedulerService]
  end
  Services -->|swift-subprocess| CLI[User's CLI binaries]
  CLI --> brew[/opt/homebrew/bin/brew]
  CLI --> mpm[mpm]
  CLI --> chezmoi[chezmoi]
  CLI --> git[/usr/bin/git]
  CLI --> defaults[defaults]
  CLI --> gitleaks[gitleaks - bundled]
  Store --> Persist[Settings + cache<br/>Application Support]
  GitSvc --> Remote[(User's git remote<br/>GitHub/GitLab/self-hosted)]
```

## Layering rules

- **UI never calls `Process` directly.** It reads `AppStore` state and
  dispatches intents to `JobRunner`.
- **Services are actors.** Each wraps exactly one CLI. They return typed
  values and optionally yield `AsyncThrowingStream<OutputChunk, Error>`.
- **Every subprocess invocation is a `Job`** with id, start time, termination
  status, and a line-buffered log. Jobs are cancellable.
- **No library linking to GPL backends.** mpm is invoked only via `Process` /
  `swift-subprocess`; chezmoi is invoked the same way. This is the licensing
  firewall — see
  [decisions/0001-ipc-not-linking.md](../decisions/0001-ipc-not-linking.md).

## Diagram caveat

The diagram above reflects the **v0.1 layering**. The target v1.x layout
(per [process/audit-2026-04.md §3](../process/audit-2026-04.md#3-architectural-gaps))
adds `Models/`, `Policy/`, `Plugins/`, `Diagnostics/`, `Secrets/` modules.
Those land in [process/implementation-plan.md](../process/implementation-plan.md)
phases 10–14.

## Related

- [reference/modules.md](modules.md) — file-level module breakdown.
- [reference/sync-model.md](sync-model.md) — push/pull semantics.
- [reference/backends/](backends/) — per-CLI integration spec.
- [explain/state-management.md](../explain/state-management.md) — why
  `@Observable` and not TCA.
