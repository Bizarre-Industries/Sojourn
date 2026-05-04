// Sojourn — AppStore
//
// The single `@Observable` root state container. Owned by `SojournApp` at
// the `@main` level; injected via `.environment(appStore)` and read via
// `@Environment(AppStore.self)`. Never `@State` at the root — see CLAUDE.md
// "Do not use @State to hold the root AppStore."
//
// v0.2 (ADR-0018): single backend is brew bundle. mpm + BackendRegistry +
// Plugins host removed. `brewBundle: BrewBundleService` replaces `mpm` +
// `managers` snapshot table; the parsed `brewfile: BrewfileAST?` is the
// in-memory source of truth.

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

  internal let brewBundle: BrewBundleService
  internal let git: GitService?
  internal let chezmoi: ChezmoiService?
  internal let pref: PrefService
  internal let secrets: SecretScanService?
  internal let brew: BrewService
  internal let snapshots: SnapshotService
  internal let cooldown: CooldownGate
  internal let cleanup: CleanupService
  internal let bootstrap: BootstrapService
  internal let containersService: ContainersService
  internal let masService: MasService
  internal let backgroundActivity: BackgroundActivity

  internal let historyDB: HistoryDB?
  internal let bootstrapCoordinator: BootstrapCoordinator

  internal var sync: SyncCoordinator?
  internal var settings: Settings = .empty
  internal var brewfile: BrewfileAST?
  internal var history: [HistoryEntry] = []
  internal var orphans: [OrphanCandidate] = []

  // v0.2 transitional: panes that read `store.managers` continue to
  // compile against an empty dictionary. Real package counts come from
  // `brewfile` once OverviewPane is rewired in step 6.
  internal var managers: [String: ManagerSnapshot] = [:]

  /// Snapshot of installed container runtimes per ADR-0023.
  /// Populated by `refreshContainers()` (called by ContainersPane on
  /// appear / "Rescan" gesture). Empty until first probe.
  internal var containers: ContainersSnapshot = .empty

  /// Last-observed SMAppService.daemon status of the MasHelper per
  /// ADR-0024. Refreshed by `refreshMasHelperStatus()` (called by
  /// PackagesPane on appear / Register / Revoke gestures).
  internal var masHelperStatus: MasHelperStatus = .notRegistered

  internal init(
    paths: AppSupportPaths,
    settingsStore: SettingsStore,
    deletionsDB: DeletionsDB,
    historyDB: HistoryDB?,
    brewBundle: BrewBundleService,
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
    self.brewBundle = brewBundle
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
    self.containersService = ContainersService(runner: runner, locator: self.toolLocator)
    self.masService = MasService()
    self.backgroundActivity = BackgroundActivity()
    self.historyDB = historyDB
    self.bootstrapCoordinator = BootstrapCoordinator(
      probe: ToolProbe(locator: toolLocator),
      installer: ToolInstaller(brew: brew)
    )
  }

  /// Bootstrap convenience — build and wire every persistence piece
  /// against the real `~/Library/Application Support/Sojourn/` layout.
  internal static func live() async throws -> AppStore {
    let paths = try AppSupportPaths()
    let settings = try SettingsStore(paths: paths)
    let deletionsURL = paths.config.appendingPathComponent("deletions.sqlite")
    let deletions = try DeletionsDB(url: deletionsURL)
    let historyURL = paths.config.appendingPathComponent("history.sqlite")
    let history = try? HistoryDB(url: historyURL)

    let runner = SubprocessRunner()
    let locator = ToolLocator()
    let brewURL = (await locator.locate("brew"))?.url
      ?? URL(fileURLWithPath: "/opt/homebrew/bin/brew")
    let brewBundle = BrewBundleService(runner: runner, brewURL: brewURL)
    let git = await GitService.live(runner: runner, locator: locator)
    let chezmoi = await ChezmoiService.live(runner: runner, locator: locator)
    let secrets = SecretScanService.live(runner: runner)

    return AppStore(
      paths: paths, settingsStore: settings, deletionsDB: deletions, historyDB: history,
      brewBundle: brewBundle, git: git, chezmoi: chezmoi, secrets: secrets
    )
  }

  /// Hydrate in-memory snapshots from disk. Safe to call multiple times.
  internal func reloadFromDisk() async {
    self.settings = await settingsStore.value
    if let historyDB, let rows = try? await historyDB.list(limit: 200) {
      self.history = rows
    } else {
      self.history = settings.history
    }
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
      brewBundle: brewBundle,
      pref: pref,
      secrets: secrets,
      snapshots: snapshots,
      cooldown: cooldown
    )
  }

  /// Append a history entry and persist it. Writes to `HistoryDB`
  /// (canonical) and mirrors into `Settings.history` for v0.1
  /// backwards compatibility — the mirror is dropped in v0.2.
  internal func recordHistory(_ entry: HistoryEntry) async {
    history.append(entry)
    if let historyDB {
      try? await historyDB.insert(entry)
    }
    var snapshot = await settingsStore.value
    snapshot.history.append(entry)
    try? await settingsStore.replace(snapshot)
  }

  /// Refresh the in-memory Brewfile snapshot via `brew bundle dump`.
  /// Runs the subprocess; on success replaces `self.brewfile`.
  internal func refreshBrewfile() async {
    if let snap = try? await brewBundle.dump() {
      self.brewfile = snap
    }
  }

  /// v0.2 transitional alias for callers (SojournApp launch hook) that
  /// expect the v0.1 `refreshManagers()` name. Removed once OverviewPane
  /// is rewired to read `brewfile` directly in step 6.
  internal func refreshManagers() async { await refreshBrewfile() }

  /// Rescan orphan candidates.
  internal func rescanOrphans() async {
    self.orphans = await cleanup.scan()
  }

  /// Refresh `containers` snapshot from ContainersService. Called by
  /// ContainersPane on appear (via cached snapshot) and on user
  /// "Rescan" gesture (via `forceRescan: true`). Per ADR-0023 perf
  /// invariants, no timer-based refresh — explicit gestures only.
  internal func refreshContainers(forceRescan: Bool = false) async {
    if forceRescan {
      self.containers = await containersService.rescan()
    } else {
      self.containers = await containersService.snapshot()
    }
  }

  /// Refresh the MasHelper status surface (per ADR-0024). Called by
  /// PackagesPane on appear and after Register / Revoke gestures.
  /// `SMAppService.status` is a synchronous synth — no subprocess.
  internal func refreshMasHelperStatus() async {
    self.masHelperStatus = await masService.status()
  }

  /// Trigger MasHelper register flow (user sees system prompt the
  /// first time). Refreshes status after.
  internal func registerMasHelper() async throws {
    try await masService.register()
    await refreshMasHelperStatus()
  }

  /// Trigger MasHelper unregister + cleanup. Refreshes status after.
  internal func unregisterMasHelper() async throws {
    try await masService.unregister()
    await refreshMasHelperStatus()
  }
}
