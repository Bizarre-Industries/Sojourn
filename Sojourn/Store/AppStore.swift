// Sojourn — AppStore
//
// The single `@Observable` root state container. Owned by `SojournApp` at
// the `@main` level; injected via `.environment(appStore)` and read via
// `@Environment(AppStore.self)`. Never `@State` at the root — see CLAUDE.md
// "Do not use @State to hold the root AppStore."
//
// Holds persistence + all long-lived service actors. Phase 10 wires
// SyncCoordinator, BootstrapService, and CleanupService into the root.

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

  internal let mpm: MPMService?
  internal let git: GitService?
  internal let chezmoi: ChezmoiService?
  internal let pref: PrefService
  internal let secrets: SecretScanService?
  internal let brew: BrewService
  internal let snapshots: SnapshotService
  internal let cooldown: CooldownGate
  internal let cleanup: CleanupService
  internal let bootstrap: BootstrapService
  internal let backgroundActivity: BackgroundActivity

  internal var sync: SyncCoordinator?
  internal var settings: Settings = .empty
  internal var managers: [String: ManagerSnapshot] = [:]
  internal var history: [HistoryEntry] = []
  internal var orphans: [OrphanCandidate] = []

  internal init(
    paths: AppSupportPaths,
    settingsStore: SettingsStore,
    deletionsDB: DeletionsDB,
    mpm: MPMService?,
    git: GitService?,
    chezmoi: ChezmoiService?,
    secrets: SecretScanService?
  ) {
    let runner = SubprocessRunner()
    self.runner = runner
    self.jobRunner = JobRunner(runner: runner)
    self.toolLocator = ToolLocator()
    self.paths = paths
    self.settingsStore = settingsStore
    let backups = BackupsDirectory(paths: paths)
    self.backups = backups
    self.deletionsDB = deletionsDB
    self.mpm = mpm
    self.git = git
    self.chezmoi = chezmoi
    self.secrets = secrets
    self.pref = PrefService.live(runner: runner)
    let brew = BrewService.live(runner: runner)
    self.brew = brew
    self.snapshots = SnapshotService.live(backups: backups, runner: runner)
    self.cooldown = CooldownGate.live(settings: settingsStore)
    self.cleanup = CleanupService(deletionsDB: deletionsDB)
    self.bootstrap = BootstrapService(locator: toolLocator, brew: brew, subprocess: runner)
    self.backgroundActivity = BackgroundActivity()
  }

  /// Bootstrap convenience — build and wire every persistence piece
  /// against the real `~/Library/Application Support/Sojourn/` layout.
  internal static func live() async throws -> AppStore {
    let paths = try AppSupportPaths()
    let settings = try SettingsStore(paths: paths)
    let deletionsURL = paths.config.appendingPathComponent("deletions.sqlite")
    let deletions = try DeletionsDB(url: deletionsURL)

    let runner = SubprocessRunner()
    let locator = ToolLocator()
    let mpm = await MPMService.live(runner: runner, locator: locator)
    let git = await GitService.live(runner: runner, locator: locator)
    let chezmoi = await ChezmoiService.live(runner: runner, locator: locator)
    let secrets = SecretScanService.live(runner: runner)

    return AppStore(
      paths: paths, settingsStore: settings, deletionsDB: deletions,
      mpm: mpm, git: git, chezmoi: chezmoi, secrets: secrets
    )
  }

  /// Hydrate in-memory snapshots from disk. Safe to call multiple times.
  internal func reloadFromDisk() async {
    self.settings = await settingsStore.value
    self.history = settings.history
    await toolLocator.seed(settings.toolLocations)
    await cleanup.loadBundledRegistry()
  }

  /// Construct a SyncCoordinator against a repo URL. Callers (typically
  /// SettingsScene after remote URL entry) invoke once the user has
  /// cloned their sojourn-data repo locally.
  internal func configureSync(repoURL: URL) {
    guard let git else { return }
    self.sync = SyncCoordinator(
      repoURL: repoURL,
      git: git,
      chezmoi: chezmoi,
      mpm: mpm,
      pref: pref,
      secrets: secrets,
      snapshots: snapshots,
      cooldown: cooldown
    )
  }

  /// Append a history entry and persist it.
  internal func recordHistory(_ entry: HistoryEntry) async {
    history.append(entry)
    var snapshot = await settingsStore.value
    snapshot.history.append(entry)
    try? await settingsStore.replace(snapshot)
  }

  /// Refresh managers via mpm. No-op if mpm is missing.
  internal func refreshManagers() async {
    guard let mpm else { return }
    if let snap = try? await mpm.installed() {
      self.managers = snap
    }
  }

  /// Rescan orphan candidates.
  internal func rescanOrphans() async {
    self.orphans = await cleanup.scan()
  }
}
