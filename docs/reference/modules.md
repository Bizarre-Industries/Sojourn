# Module breakdown

The directory layout under `Sojourn/`. The target layout adds `Models/`,
`Policy/`, `Plugins/`, `Diagnostics/`, `Secrets/` (per
[process/audit-2026-04.md §3](../process/audit-2026-04.md#3-architectural-gaps);
landing in [process/implementation-plan.md](../process/implementation-plan.md)
phases 10–14).

```
App/
  SojournApp.swift             // @main, WindowGroup + MenuBarExtra scenes
  AppStore.swift               // @Observable root
  Settings.swift               // Codable, persisted
Models/
  ManagerSnapshot.swift        // per-manager package list value type
  AutoUpdateTier.swift         // A–E tier enum + ManagerTier defaults
  Conflict.swift               // 6 sync conflict shapes
  Snapshot.swift               // pre-op tarball metadata
  HistoryEntry.swift           // post-hoc sync record
  Job.swift                    // in-flight subprocess metadata
  DotfileOwner.swift           // cruft-detection mapping entry
  OrphanCandidate.swift        // safe/review/risky classification
  PreferenceDomain.swift       // user/system/sandboxed/apple-internal layer
Services/
  SubprocessRunner.swift       // wraps swift-subprocess
  BrewService.swift            // actor
  MPMService.swift             // actor; JSON decode
  ChezmoiService.swift         // actor
  GitService.swift             // actor; /usr/bin/git
  PrefService.swift            // actor; defaults export/import, plutil
  SecretScanService.swift      // actor; gitleaks
  BootstrapService.swift       // actor
  GitHubDeviceAuth.swift       // URLSession + Keychain
  ToolLocator.swift            // hardcoded candidate paths
  ToolInventory.swift          // snapshot value type
Jobs/
  JobRunner.swift              // owns Tasks; pipes to LogBuffer
  LogBuffer.swift              // @Observable ring buffer, AttributedString rows
  ANSIParser.swift             // SGR -> AttributeContainer
Scheduling/
  BackgroundActivity.swift     // NSBackgroundActivityScheduler wrapper
Sync/
  SyncCoordinator.swift        // push/pull orchestration
  MachineMetadata.swift        // .sojourn/machines/*.toml
UI/
  MainWindowView.swift         // NavigationSplitView
  MenuBarRootView.swift
  BootstrapView.swift
  LogConsoleView.swift
  PackagesPane.swift
  DotfilesPane.swift
  PreferencesPane.swift
  HistoryPane.swift
  MachinesPane.swift
  SecretPromptSheet.swift
Data/
  applications/*.toml          // Mackup-derived, re-classified
  dotfile_owners.toml          // cruft-detection mapping
  .gitleaks.toml               // default rules
```

## Platform and dependencies

- macOS 14+ (Sonoma and later). macOS 14 is ~18 months old by v1 ship; this
  is an acceptable floor given the target audience.
- Swift 6.1+ toolchain.
- SPM dependencies: `swiftlang/swift-subprocess`
  (pin `.upToNextMinor(from: "0.4.0")`); `orchetect/MenuBarExtraAccess`
  (escape hatch for `MenuBarExtra`). That's it. No TCA, no SwiftGit2, no
  SwiftShell, no libgit2.

## Bundled binaries

`Contents/Resources/bin/`: `gitleaks`, `age`. Both re-signed with Sojourn's
Developer ID under `--options=runtime` and stapled as part of outer
notarization. Nothing else bundled — brew, mpm, chezmoi all live in the
user's `PATH` and are installed via the bootstrap flow. See
[decisions/0009-bundle-binary-policy.md](../decisions/0009-bundle-binary-policy.md).

## State management

Raw `@Observable`, not TCA. See
[explain/state-management.md](../explain/state-management.md) and
[decisions/0005-no-tca.md](../decisions/0005-no-tca.md).

## Subprocess execution

`swift-subprocess` with raw `Process + Pipe + AsyncStream` fallback. See
[reference/backends/](backends/) for per-CLI integration detail.

## Streaming output

Pipeline: bytes → line splitter (actor) → ANSI SGR parser (strip to
`AttributedString`) → ring-buffered `@Observable LogBuffer` → SwiftUI
`LazyVStack` of `AttributedString` rows with `.monospaced()` and
`.textSelection(.enabled)`.

Strip ANSI by default. Ship a `SwiftTerm`-based full-VT100 pane as an
optional "Advanced" tab for users who want to run arbitrary brew commands
manually. SwiftTerm is used in Secure Shellfish and La Terminal;
well-supported.

## Menu bar

`MenuBarExtra(.window)` + `MenuBarExtraAccess`. The `.window` style gives a
full SwiftUI popover (list of active jobs, quick upgrade, reveal main
window).

## Main window

`NavigationSplitView` 3-pane:

- **Left sidebar**: source picker — Packages, Dotfiles, Preferences, History,
  Machines, Settings.
- **Middle list**: context-sensitive (e.g., manager list for Packages;
  managed-file tree for Dotfiles).
- **Right detail**: item detail + actions + (when running) embedded log
  pane.

## Scheduling

`NSBackgroundActivityScheduler` in-process. Activity id
`app.bizarre.sojourn.refresh-outdated`, interval 1h, tolerance 15m, QoS
`.utility`. See [reference/cooldown-policy.md](cooldown-policy.md) for the
full spec.
