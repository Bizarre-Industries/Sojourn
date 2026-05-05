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
  internal struct MacOSFeatureStatusRow: Sendable, Hashable, Identifiable {
    internal let id: String
    internal let title: String
    internal let value: String
    internal let detail: String
    internal let symbol: String
  }

  private enum GenerationRefreshResult: Sendable {
    case success([GenerationManifest])
    case missingDirectory
    case failure(String)
  }

  internal let runner: SubprocessRunner
  internal let jobRunner: JobRunner
  internal let toolLocator: ToolLocator
  internal let paths: AppSupportPaths
  internal let settingsStore: SettingsStore
  internal let backups: BackupsDirectory
  internal let deletionsDB: DeletionsDB

  internal let brewBundle: BrewBundleService
  internal let brewURL: URL
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
  internal let generationService: GenerationService
  internal let macOSFeatures: MacOSFeaturesService
  internal var advisoryService: AdvisoryService
  internal let masService: MasService
  internal let sparkleService: SparkleService
  internal let backgroundActivity: BackgroundActivity

  internal let historyDB: HistoryDB?
  internal let bootstrapCoordinator: BootstrapCoordinator

  internal var sync: SyncCoordinator?
  /// Multi-machine conflict resolver per ADR-0026. Lifecycle matches
  /// `sync`: instantiated by `configureSync(repoURL:)` and shared with
  /// the SyncCoordinator that observes its state for pull/push gating.
  internal var conflictResolver: ConflictResolver?
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
  internal var generations: [GenerationManifest] = []
  internal var generationLoadError: String?
  internal var touchIDForSudoEnabled: Bool = false
  internal var macOSFeatureRows: [MacOSFeatureStatusRow] = []
  internal var preferenceDomains: [PreferenceDomainEntry] = []
  internal var advisorySnapshot = AdvisorySnapshot(
    advisories: [],
    freshness: .unavailable,
    lastSuccessAt: nil,
    lastAttemptAt: nil,
    cacheKeySHA256: nil
  )
  internal var advisoryMessage: String?

  /// Last-observed SMAppService.daemon status of the MasHelper per
  /// ADR-0024. Refreshed by `refreshMasHelperStatus()` (called by
  /// PackagesPane on appear / Register / Revoke gestures).
  internal var masHelperStatus: MasHelperStatus = .notRegistered

  @ObservationIgnored private var brewfileRefreshTask: Task<BrewfileAST?, Never>?
  @ObservationIgnored private var containersRefreshTask: Task<ContainersSnapshot, Never>?
  @ObservationIgnored private var generationsRefreshTask: Task<GenerationRefreshResult, Never>?
  @ObservationIgnored private var macOSFeatureRefreshTask: Task<(Bool, [MacOSFeatureStatusRow]), Never>?
  @ObservationIgnored private var advisoryRefreshTask: Task<AdvisorySnapshot, Never>?
  @ObservationIgnored private var preferenceDomainsRefreshTask: Task<[PreferenceDomainEntry], Never>?
#if DEBUG
  @ObservationIgnored internal private(set) var debugContainersRefreshStarts = 0
#endif

  internal init(
    paths: AppSupportPaths,
    settingsStore: SettingsStore,
    deletionsDB: DeletionsDB,
    historyDB: HistoryDB?,
    brewBundle: BrewBundleService,
    brewURL: URL = URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
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
    self.brewURL = brewURL
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
    self.generationService = GenerationService(runner: runner, paths: paths)
    self.macOSFeatures = MacOSFeaturesService(runner: runner)
    self.advisoryService = AdvisoryService(
      runner: runner,
      brewURL: brewURL,
      chezmoiSourceRoot: paths.config.appendingPathComponent("sojourn-data", isDirectory: true),
      cacheURL: paths.cache.appendingPathComponent("advisories.json")
    )
    self.masService = MasService()
    self.sparkleService = SparkleService()
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
    let sourceRoot = paths.config.appendingPathComponent("sojourn-data", isDirectory: true)
    let brewBundle = BrewBundleService(
      runner: runner,
      brewURL: brewURL,
      chezmoiSourceRoot: sourceRoot
    )
    let git = await GitService.live(runner: runner, locator: locator)
    let chezmoi = await ChezmoiService.live(runner: runner, locator: locator)
    let secrets = SecretScanService.live(runner: runner)

    return AppStore(
      paths: paths, settingsStore: settings, deletionsDB: deletions, historyDB: history,
      brewBundle: brewBundle, brewURL: brewURL, git: git, chezmoi: chezmoi, secrets: secrets
    )
  }

  /// Hydrate in-memory snapshots from disk. Safe to call multiple times.
  internal func reloadFromDisk() async {
    self.settings = await settingsStore.value
    await resolveInstallSourceIfNeeded()
    if let historyDB, let rows = try? await historyDB.list(limit: 200) {
      self.history = rows
    } else {
      self.history = settings.history
    }
    await toolLocator.seed(settings.toolLocations)
    await cleanup.loadBundledRegistry()
    await advisoryService.loadFromDisk()
    self.advisorySnapshot = await advisoryService.currentSnapshot()
  }

  /// Persist ADR-0020 install-source classification on first launch.
  /// Unknown installs fail open to Sparkle so direct-DMG users keep an
  /// update path even when detection cannot prove the install source.
  internal func resolveInstallSourceIfNeeded() async {
    guard settings.installSource == nil else {
      if settings.effectiveInstallSource == .cask {
        sparkleService.suppressForCaskInstall()
      }
      return
    }

    let detected = InstallSourceDetector.detect()
    do {
      var snapshot = await settingsStore.value
      snapshot.installSource = detected
      try await settingsStore.replace(snapshot)
      self.settings = snapshot
    } catch {
      self.settings.installSource = detected
    }
    if detected == .cask {
      sparkleService.suppressForCaskInstall()
    }
  }

  internal var canCheckForUpdates: Bool {
    settings.effectiveInstallSource.allowsSparkleUpdates
      && sparkleService.canCheckForUpdates
  }

  internal func startSparkleIfEligible() async {
    await resolveInstallSourceIfNeeded()
    guard settings.effectiveInstallSource.allowsSparkleUpdates else {
      sparkleService.suppressForCaskInstall()
      return
    }
    sparkleService.start()
  }

  internal func checkForUpdates() async {
    await resolveInstallSourceIfNeeded()
    guard settings.effectiveInstallSource.allowsSparkleUpdates else {
      sparkleService.suppressForCaskInstall()
      return
    }
    sparkleService.checkForUpdates()
  }

  /// Construct a SyncCoordinator against a repo URL. Callers (typically
  /// SettingsScene after remote URL entry) invoke once the user has
  /// cloned their sojourn-data repo locally.
  internal func configureSync(repoURL: URL) {
    guard let git else { return }
    let resolver = ConflictResolver(git: git, repoURL: repoURL)
    self.conflictResolver = resolver
    self.sync = SyncCoordinator(
      repoURL: repoURL,
      git: git,
      chezmoi: chezmoi,
      brewBundle: brewBundle,
      pref: pref,
      secrets: secrets,
      snapshots: snapshots,
      cooldown: cooldown,
      conflictResolver: resolver
    )
  }

  internal func pullSync() async {
    await sync?.pull()
  }

  internal func applyReviewedPull() async {
    await sync?.applyReviewedPull()
  }

  internal func cancelSyncOperation() {
    sync?.cancelActiveOperation()
  }

  internal func pushSync(message: String = "sojourn: sync") async {
    await sync?.push(message: message)
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
  internal func refreshBrewfile(force: Bool = false) async {
    if !force, brewfile != nil { return }
    if let task = brewfileRefreshTask {
      if let snap = await task.value {
        self.brewfile = snap
      }
      return
    }

    let task = Task { [brewBundle, brewURL, jobRunner] in
      try? await jobRunner.track(JobRequest(
        label: "Refresh Brewfile",
        tool: brewURL,
        args: ["bundle", "dump", "--file=-", "--all"],
        timeout: 120,
        kind: .advisory
      )) {
        try await brewBundle.dump()
      }
    }
    brewfileRefreshTask = task
    let snap = await task.value
    brewfileRefreshTask = nil
    if let snap {
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
    if let task = containersRefreshTask {
      self.containers = await task.value
      return
    }

#if DEBUG
    debugContainersRefreshStarts += 1
#endif
    let task = Task { [containersService] in
      if forceRescan {
        return await containersService.rescan()
      }
      return await containersService.snapshot()
    }
    containersRefreshTask = task
    self.containers = await task.value
    containersRefreshTask = nil
  }

  /// Refresh on-disk generation manifests. Listing is pure file IO, but
  /// still flows through AppStore so panes do not talk to services
  /// directly.
  internal func refreshGenerations() async {
    if let task = generationsRefreshTask {
      applyGenerationRefresh(await task.value)
      return
    }

    let task = Task.detached { [generationService] in
      do {
        return GenerationRefreshResult.success(try await generationService.list())
      } catch GenerationError.generationsDirMissing(_) {
        return GenerationRefreshResult.missingDirectory
      } catch {
        return GenerationRefreshResult.failure(String(describing: error))
      }
    }
    generationsRefreshTask = task
    applyGenerationRefresh(await task.value)
    generationsRefreshTask = nil
  }

  private func applyGenerationRefresh(_ result: GenerationRefreshResult) {
    switch result {
    case .success(let generations):
      self.generations = generations
      self.generationLoadError = nil
    case .missingDirectory:
      self.generations = []
      self.generationLoadError = nil
    case .failure(let error):
      self.generations = []
      self.generationLoadError = error
    }
  }

  internal func refreshMacOSFeatureSnapshot(force: Bool = false) async {
    if !force, !macOSFeatureRows.isEmpty {
      return
    }
    if let task = macOSFeatureRefreshTask {
      let snapshot = await task.value
      self.touchIDForSudoEnabled = snapshot.0
      self.macOSFeatureRows = snapshot.1
      return
    }

    let task = Task { [macOSFeatures] in
      await Self.makeMacOSFeatureSnapshot(macOSFeatures: macOSFeatures)
    }
    macOSFeatureRefreshTask = task
    let snapshot = await task.value
    self.touchIDForSudoEnabled = snapshot.0
    self.macOSFeatureRows = snapshot.1
    macOSFeatureRefreshTask = nil
  }

  internal func refreshAdvisorySnapshot(force: Bool = false) async {
    if let task = advisoryRefreshTask {
      self.advisorySnapshot = await task.value
      applyAdvisoryMessage(force: force)
      return
    }

    let task = Task { [advisoryService] in
      await advisoryService.loadFromDisk()
      return await advisoryService.currentSnapshot()
    }
    advisoryRefreshTask = task
    self.advisorySnapshot = await task.value
    advisoryRefreshTask = nil
    applyAdvisoryMessage(force: force)
  }

  private func applyAdvisoryMessage(force: Bool) {
    if force {
      self.advisoryMessage = advisorySnapshot.advisories.isEmpty
        ? String(localized: "No cached advisory snapshot. Run an advisory scan after Homebrew vulnerability data is configured, then refresh this pane.")
        : String(localized: "Reloaded cached advisory snapshot.")
    }
  }

  internal func refreshPreferenceDomains() async {
    if let task = preferenceDomainsRefreshTask {
      self.preferenceDomains = await task.value
      return
    }

    let task = Task.detached { [pref] in
      pref.loadDomainCorpus()
    }
    preferenceDomainsRefreshTask = task
    self.preferenceDomains = await task.value
    preferenceDomainsRefreshTask = nil
  }

  private nonisolated static func makeMacOSFeatureSnapshot(
    macOSFeatures: MacOSFeaturesService
  ) async -> (Bool, [MacOSFeatureStatusRow]) {
    let touchID = macOSFeatures.isTouchIDForSudoEnabled()

    var rows: [MacOSFeatureStatusRow] = [
      MacOSFeatureStatusRow(
        id: "touch-id-sudo",
        title: "Touch ID for sudo",
        value: touchID ? "Enabled" : "Disabled",
        detail: "/etc/pam.d/sudo",
        symbol: "touchid"
      )
    ]

    for key in FinderDefault.allCases {
      rows.append(await finderFeatureRow(key, macOSFeatures: macOSFeatures))
    }

    rows.append(await stringFeatureRow(
      id: "keyboard-initial-repeat",
      title: "Initial key repeat",
      domain: "NSGlobalDomain",
      key: "InitialKeyRepeat",
      symbol: "keyboard",
      macOSFeatures: macOSFeatures
    ))
    rows.append(await stringFeatureRow(
      id: "keyboard-repeat-rate",
      title: "Key repeat",
      domain: "NSGlobalDomain",
      key: "KeyRepeat",
      symbol: "keyboard",
      macOSFeatures: macOSFeatures
    ))
    rows.append(await stringFeatureRow(
      id: "screencapture-location",
      title: "Screenshot location",
      domain: "com.apple.screencapture",
      key: "location",
      symbol: "camera.viewfinder",
      macOSFeatures: macOSFeatures
    ))
    rows.append(await stringFeatureRow(
      id: "screencapture-type",
      title: "Screenshot type",
      domain: "com.apple.screencapture",
      key: "type",
      symbol: "photo",
      macOSFeatures: macOSFeatures
    ))
    rows.append(await stringFeatureRow(
      id: "login-window-text",
      title: "Login window text",
      domain: "/Library/Preferences/com.apple.loginwindow",
      key: "LoginwindowText",
      symbol: "rectangle.and.pencil.and.ellipsis",
      macOSFeatures: macOSFeatures
    ))

    return (touchID, rows)
  }

  private nonisolated static func finderFeatureRow(
    _ key: FinderDefault,
    macOSFeatures: MacOSFeaturesService
  ) async -> MacOSFeatureStatusRow {
    let value: String
    do {
      if key == .preferredViewStyle {
        value = try await macOSFeatures.readString(domain: key.domain, key: key.rawValue) ?? "Unknown"
      } else if let enabled = try await macOSFeatures.readFinderDefault(key) {
        value = enabled ? "Enabled" : "Disabled"
      } else {
        value = "Unknown"
      }
    } catch {
      value = "Unknown"
    }
    return MacOSFeatureStatusRow(
      id: "finder-\(key.rawValue)",
      title: finderTitle(for: key),
      value: value,
      detail: "\(key.domain) / \(key.rawValue)",
      symbol: "finder"
    )
  }

  private nonisolated static func stringFeatureRow(
    id: String,
    title: String,
    domain: String,
    key: String,
    symbol: String,
    macOSFeatures: MacOSFeaturesService
  ) async -> MacOSFeatureStatusRow {
    let value: String
    do {
      value = try await macOSFeatures.readString(domain: domain, key: key) ?? "Unknown"
    } catch {
      value = "Unknown"
    }
    return MacOSFeatureStatusRow(
      id: id,
      title: title,
      value: value.isEmpty ? "Empty" : value,
      detail: "\(domain) / \(key)",
      symbol: symbol
    )
  }

  private nonisolated static func finderTitle(for key: FinderDefault) -> String {
    switch key {
    case .showAllExtensions:  return "Show all filename extensions"
    case .showPathbar:        return "Show path bar"
    case .showStatusBar:      return "Show status bar"
    case .showHiddenFiles:    return "Show hidden files"
    case .sortFoldersFirst:   return "Sort folders first"
    case .preferredViewStyle: return "Preferred Finder view"
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
