// Sojourn — AppStore
//
// The single `@Observable` root state container. Owned by `SojournApp` at
// the `@main` level; injected via `.environment(appStore)` and read via
// `@Environment(AppStore.self)`. Never `@State` at the root — see CLAUDE.md
// "Do not use @State to hold the root AppStore."
//
// Phase 2 extension: holds `SettingsStore`, `BackupsDirectory`, `DeletionsDB`,
// and the live `Settings` snapshot. Phase 3 will add the service actors
// (Git, MPM, Chezmoi, Pref, SecretScan, Brew, Bootstrap, GitHubDeviceAuth).

import Foundation
import Observation

@Observable
@MainActor
internal final class AppStore {
  internal let runner: SubprocessRunner
  internal let jobRunner: JobRunner
  internal let toolLocator: ToolLocator
  internal let paths: AppSupportPaths
  internal let settingsStore: SettingsStore
  internal let backups: BackupsDirectory
  internal let deletionsDB: DeletionsDB

  internal var settings: Settings = .empty
  internal var managers: [String: ManagerSnapshot] = [:]
  internal var history: [HistoryEntry] = []

  internal init(paths: AppSupportPaths, settingsStore: SettingsStore, deletionsDB: DeletionsDB) {
    let runner = SubprocessRunner()
    self.runner = runner
    self.jobRunner = JobRunner(runner: runner)
    self.toolLocator = ToolLocator()
    self.paths = paths
    self.settingsStore = settingsStore
    self.backups = BackupsDirectory(paths: paths)
    self.deletionsDB = deletionsDB
  }

  /// Bootstrap convenience — build and wire every persistence piece
  /// against the real `~/Library/Application Support/Sojourn/` layout.
  internal static func live() throws -> AppStore {
    let paths = try AppSupportPaths()
    let settings = try SettingsStore(paths: paths)
    let deletionsURL = paths.config.appendingPathComponent("deletions.sqlite")
    let deletions = try DeletionsDB(url: deletionsURL)
    return AppStore(paths: paths, settingsStore: settings, deletionsDB: deletions)
  }

  /// Hydrate in-memory snapshots from disk. Safe to call multiple times.
  internal func reloadFromDisk() async {
    self.settings = await settingsStore.value
    self.history = settings.history
    await toolLocator.seed(settings.toolLocations)
  }

  /// Append a history entry and persist it.
  internal func recordHistory(_ entry: HistoryEntry) async {
    history.append(entry)
    var snapshot = await settingsStore.value
    snapshot.history.append(entry)
    try? await settingsStore.replace(snapshot)
  }
}
