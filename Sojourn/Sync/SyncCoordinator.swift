// Sojourn — SyncCoordinator
//
// Orchestrates push (local → remote) and pull (remote → local) against the
// user's data repo. Pull must complete + resolve any conflicts before push
// is allowed. Pre-op snapshot on every destructive step.
//
// v0.2 (ADR-0018): the package source of truth is `Brewfile.common` +
// `Brewfile.<hostname>` (brew bundle), no longer `packages.toml` (mpm).

import Foundation
import Observation
import CryptoKit

internal enum SyncPhase: Sendable, Equatable {
  case idle
  case pulling
  case resolvingConflicts([Conflict])
  /// Remote has commits not present locally. UI surfaces ConflictResolver
  /// modal listing inbound commits + 3-button choice (rebase / merge /
  /// abort). Per ADR-0026 refuse-and-show-diff state machine.
  case awaitingPullDecision([InboundCommit])
  /// Remote state has been pulled but contains executable apply risk
  /// requiring an explicit second user gesture before chezmoi or brew
  /// mutate the machine.
  case awaitingPullApplyReview(PullApplyReview)
  /// User approved the pulled scripts/packages and Sojourn is now
  /// applying them. Carries the current user-visible step.
  case applyingReviewedPull(String)
  case scanningSecrets
  case pushing
  case done(HistoryEntry.Kind)
  case failed(String)
}

internal struct PullApplyReview: Sendable, Equatable {
  internal static let previewLimit = 500

  internal let chezmoiScripts: [String]
  internal let chezmoiTemplates: [String]
  internal let packageReviews: [PullPackageReview]
  internal let omittedChezmoiScriptCount: Int
  internal let omittedChezmoiTemplateCount: Int
  internal let omittedPackageReviewCount: Int
  internal let contentFingerprint: String

  internal init(
    chezmoiScripts: [String],
    chezmoiTemplates: [String] = [],
    packageReviews: [PullPackageReview],
    omittedChezmoiScriptCount: Int = 0,
    omittedChezmoiTemplateCount: Int = 0,
    omittedPackageReviewCount: Int = 0,
    contentFingerprint: String = ""
  ) {
    self.chezmoiScripts = chezmoiScripts
    self.chezmoiTemplates = chezmoiTemplates
    self.packageReviews = packageReviews
    self.omittedChezmoiScriptCount = omittedChezmoiScriptCount
    self.omittedChezmoiTemplateCount = omittedChezmoiTemplateCount
    self.omittedPackageReviewCount = omittedPackageReviewCount
    self.contentFingerprint = contentFingerprint
  }

  internal var requiresConsent: Bool {
    totalChezmoiScriptCount > 0
      || totalChezmoiTemplateCount > 0
      || totalPackageReviewCount > 0
  }

  internal var totalChezmoiScriptCount: Int {
    chezmoiScripts.count + omittedChezmoiScriptCount
  }

  internal var totalChezmoiTemplateCount: Int {
    chezmoiTemplates.count + omittedChezmoiTemplateCount
  }

  internal var totalPackageReviewCount: Int {
    packageReviews.count + omittedPackageReviewCount
  }

  internal var summary: String {
    var parts: [String] = []
    if totalChezmoiScriptCount > 0 {
      parts.append("\(totalChezmoiScriptCount) chezmoi script(s)")
    }
    if totalChezmoiTemplateCount > 0 {
      parts.append("\(totalChezmoiTemplateCount) chezmoi template(s)")
    }
    if totalPackageReviewCount > 0 {
      parts.append("\(totalPackageReviewCount) Brewfile entr\(totalPackageReviewCount == 1 ? "y" : "ies")")
    }
    return parts.isEmpty ? "No executable pull-apply changes need review." : parts.joined(separator: ", ")
  }

  internal var accessibilitySummary: String {
    if requiresConsent {
      return "Pull apply review required for \(summary)."
    }
    return summary
  }
}

internal struct PullPackageReview: Sendable, Equatable, Identifiable {
  internal var id: String { "\(brewfile):\(manager):\(package)" }
  internal let brewfile: String
  internal let manager: String
  internal let package: String
  internal let reason: String

  internal var accessibilityLabel: String {
    "\(manager) \(package) in \(brewfile). \(reason)"
  }
}

@Observable
@MainActor
internal final class SyncCoordinator {
  internal private(set) var phase: SyncPhase = .idle
  @ObservationIgnored private var reviewedApplyTask: Task<Void, Never>?

  internal var isOperationActive: Bool {
    switch phase {
    case .pulling, .resolvingConflicts, .applyingReviewedPull, .scanningSecrets, .pushing:
      return true
    case .idle, .awaitingPullDecision, .awaitingPullApplyReview, .done, .failed:
      return false
    }
  }

  private let repoURL: URL
  private let git: GitService
  private let chezmoi: ChezmoiService?
  private let brewBundle: BrewBundleService
  private let pref: PrefService?
  private let secrets: SecretScanService?
  private let snapshots: SnapshotService
  private let cooldown: CooldownGate
  internal let conflictResolver: ConflictResolver

  internal init(
    repoURL: URL,
    git: GitService,
    chezmoi: ChezmoiService?,
    brewBundle: BrewBundleService,
    pref: PrefService?,
    secrets: SecretScanService?,
    snapshots: SnapshotService,
    cooldown: CooldownGate,
    conflictResolver: ConflictResolver
  ) {
    self.repoURL = repoURL
    self.git = git
    self.chezmoi = chezmoi
    self.brewBundle = brewBundle
    self.pref = pref
    self.secrets = secrets
    self.snapshots = snapshots
    self.cooldown = cooldown
    self.conflictResolver = conflictResolver
  }

  // MARK: - Pull

  internal func pull(branch: String = "main") async {
    guard !isOperationActive else {
      SojournLog.sync.error("pull ignored: sync operation already in progress")
      return
    }
    guard !hasPendingPullApplyReview else {
      SojournLog.sync.error("pull ignored: pulled changes are waiting for apply review")
      return
    }

    let signpost = SojournSignpost.sync
    let state = signpost.beginInterval("pull", id: signpost.makeSignpostID())
    SojournLog.sync.info("pull start branch=\(branch, privacy: .public)")

    // ADR-0026 refuse-and-show-diff: detect divergence first. If
    // remote moved while we were offline, surface inbound commits via
    // ConflictResolver and return — the user picks rebase / merge /
    // abort, then SyncPane re-invokes pull which reaches this point
    // with `.clean` or `.resolved`.
    phase = .pulling
    // Reset .blockedFromPush from a prior abort so a fresh pull can
    // re-detect and surface inbound commits anew (council 2026-05-04
    // stage5 architect condition: blocked is recoverable).
    if case .blockedFromPush = conflictResolver.state {
      conflictResolver.reset()
    }
    await conflictResolver.detect(branch: branch)
    switch conflictResolver.state {
    case .conflictPending(let commits):
      phase = .awaitingPullDecision(commits)
      SojournLog.sync.info("pull paused: \(commits.count, privacy: .public) inbound commits")
      signpost.endInterval("pull", state)
      return
    case .failed(let msg):
      phase = .failed("pull pre-check failed: \(msg)")
      signpost.endInterval("pull", state)
      return
    case .clean, .resolved:
      break  // proceed
    case .detecting, .resolving, .blockedFromPush:
      // Resolver should not be in these states after `detect` returns
      // (blocked is reset above; detecting/resolving guarded by
      // detect's idempotency).
      phase = .failed("pull pre-check left resolver in unexpected state")
      signpost.endInterval("pull", state)
      return
    }

    do {
      try await git.pull(remote: "origin", branch: branch, cwd: repoURL)
      let review = try await pullApplyReview()
      if review.requiresConsent {
        phase = .awaitingPullApplyReview(review)
        SojournLog.sync.info("pull paused for apply review: \(review.summary, privacy: .public)")
        signpost.endInterval("pull", state)
        return
      }
      _ = try await snapshots.capture(operation: .syncPull, sources: [repoURL])
      try await applyPulledState()
      phase = .done(.syncPull)
      SojournLog.sync.info("pull done")
    } catch {
      phase = .failed("pull failed: \(error)")
      SojournLog.sync.error("pull failed: \(String(describing: error), privacy: .public)")
    }
    signpost.endInterval("pull", state)
  }

  internal func applyReviewedPull() async {
    guard case .awaitingPullApplyReview(let review) = phase else {
      phase = .failed("No reviewed pull is waiting to apply.")
      return
    }

    let task = Task { @MainActor in
      await runReviewedPullApply(review: review)
    }
    reviewedApplyTask = task
    await task.value
  }

  internal func cancelActiveOperation() {
    reviewedApplyTask?.cancel()
  }

  internal func discardPullApplyReview() {
    guard case .awaitingPullApplyReview = phase else { return }
    phase = .failed(String(localized: "Pulled changes were left unapplied. Rerun Pull and Apply to review them again."))
  }

  private func runReviewedPullApply(review: PullApplyReview) async {
    phase = .applyingReviewedPull(String(localized: "Verifying reviewed content"))
    do {
      try Task.checkCancellation()
      let currentReview = try await pullApplyReview()
      guard currentReview.contentFingerprint == review.contentFingerprint else {
        phase = .failed(String(localized: "Pulled content changed after review. Rerun Pull and Apply so Sojourn can rebuild the script and package review before applying."))
        return
      }

      phase = .applyingReviewedPull(String(localized: "Creating generation"))
      _ = try await snapshots.capture(operation: .syncPull, sources: [repoURL])
      try Task.checkCancellation()
      try await applyPulledState(reportReviewedApplyStep: true)
      phase = .done(.syncPull)
      SojournLog.sync.info("reviewed pull apply done")
    } catch is CancellationError {
      phase = .failed(String(localized: "Reviewed pull apply cancelled before completion. Pull remains fetched; rerun Pull and Apply to review again."))
      SojournLog.sync.info("reviewed pull apply cancelled")
    } catch {
      phase = .failed("reviewed pull apply failed: \(error)")
      SojournLog.sync.error("reviewed pull apply failed: \(String(describing: error), privacy: .public)")
    }
    reviewedApplyTask = nil
  }

  // MARK: - Push

  internal func push(branch: String = "main", message: String) async {
    guard !isOperationActive else {
      SojournLog.sync.error("push ignored: sync operation already in progress")
      return
    }
    guard !hasPendingPullApplyReview else {
      SojournLog.sync.error("push ignored: pulled changes are waiting for apply review")
      return
    }

    let signpost = SojournSignpost.sync
    let state = signpost.beginInterval("push", id: signpost.makeSignpostID())
    defer { signpost.endInterval("push", state) }
    SojournLog.sync.info("push start branch=\(branch, privacy: .public)")

    // ADR-0026: refuse push if ConflictResolver knows about unresolved
    // inbound work. The cooperative writer lock alone is insufficient
    // for a Mac that was offline when another acquired.
    guard conflictResolver.canPush else {
      let reason = conflictResolver.pushBlockedReason
      SojournLog.sync.error("push blocked: \(reason, privacy: .public)")
      phase = .failed(reason)
      return
    }

    phase = .pushing
    do {
      let host = Self.hostname()
      let syncFiles = [
        "Brewfile.common",
        "Brewfile.\(host)",
        "dotfiles",
        "prefs",
        ".sojourn"
      ]
      let stageable = syncFiles
        .map { repoURL.appendingPathComponent($0) }
        .filter { FileManager.default.fileExists(atPath: $0.path) }
        .map { $0.lastPathComponent }
      if !stageable.isEmpty {
        try await git.add(paths: stageable, cwd: repoURL)
        let stagedPaths = try await git.stagedPaths(cwd: repoURL)
        let unexpected = stagedPaths.filter { !Self.isSyncPath($0, under: stageable) }
        if !unexpected.isEmpty {
          await failAfterUnstage(
            paths: stageable,
            blockedMessage: Self.unexpectedStagedPathsMessage(unexpected)
          )
          return
        }
        phase = .scanningSecrets
        guard let secrets else {
          await failAfterUnstage(
            paths: stageable,
            blockedMessage: String(localized: "Push blocked because secret scanning is unavailable. Re-run bootstrap so Sojourn can locate gitleaks, then push again.")
          )
          return
        }
        do {
          let findings = try await secrets.scanStaged(cwd: repoURL)
          let highConfidence = findings.filter(\.isHighConfidence)
          if !highConfidence.isEmpty {
            SojournLog.secrets.error(
              "blocked push: \(highConfidence.count) high-confidence finding(s)"
            )
            await failAfterUnstage(
              paths: stageable,
              blockedMessage: Self.secretScanBlockedMessage(for: highConfidence)
            )
            return
          }
        } catch {
          SojournLog.secrets.error("gitleaks failed: \(String(describing: error), privacy: .public)")
          await failAfterUnstage(
            paths: stageable,
            blockedMessage: String(localized: "Push blocked because gitleaks could not scan the staged sync files. Resolve the scan error, then push again. Cause: \(String(describing: error))")
          )
          return
        }
        _ = try await snapshots.capture(operation: .syncPush, sources: [repoURL])
        phase = .pushing
        _ = try await git.commit(message: message, signoff: true, paths: stageable, cwd: repoURL)
      } else {
        _ = try await snapshots.capture(operation: .syncPush, sources: [repoURL])
      }
      try await git.push(remote: "origin", branch: branch, cwd: repoURL)
      phase = .done(.syncPush)
    } catch {
      phase = .failed("push failed: \(error)")
    }
  }

  private func failAfterUnstage(paths: [String], blockedMessage: String) async {
    do {
      try await git.unstage(paths: paths, cwd: repoURL)
      phase = .failed(blockedMessage)
    } catch {
      SojournLog.secrets.error(
        "failed to unstage blocked push paths: \(String(describing: error), privacy: .public)"
      )
      phase = .failed(
        blockedMessage + " " + String(localized: "Cleanup also failed; staged sync files may still contain blocked content. Run git reset -- Brewfile.common Brewfile.<host> dotfiles prefs .sojourn in the data repo before retrying. Cause: \(String(describing: error))")
      )
    }
  }

  private nonisolated static func secretScanBlockedMessage(
    for findings: [SecretFinding]
  ) -> String {
    let listed = findings.prefix(3).map {
      "\($0.file):\($0.startLine) (\($0.ruleID))"
    }.joined(separator: ", ")
    let remaining = findings.count - min(findings.count, 3)
    let suffix = remaining > 0 ? ", and \(remaining) more" : ""
    return String(localized: "Push blocked by secret scan. \(findings.count) high-confidence finding(s) in staged sync files: \(listed)\(suffix). Remove the secret or add a repo allowlist entry, then push again.")
  }

  private nonisolated static func isSyncPath(_ path: String, under roots: [String]) -> Bool {
    roots.contains { root in
      path == root || path.hasPrefix(root + "/")
    }
  }

  private nonisolated static func unexpectedStagedPathsMessage(_ paths: [String]) -> String {
    let listed = paths.prefix(3).joined(separator: ", ")
    let remaining = paths.count - min(paths.count, 3)
    let suffix = remaining > 0 ? ", and \(remaining) more" : ""
    return String(localized: "Push blocked because the data repo already has staged files outside Sojourn sync paths: \(listed)\(suffix). Unstage those files, then push again.")
  }

  internal func reset() {
    phase = .idle
  }

  private var hasPendingPullApplyReview: Bool {
    if case .awaitingPullApplyReview = phase {
      return true
    }
    return false
  }

  // MARK: - Pull apply review

  private func applyPulledState(reportReviewedApplyStep: Bool = false) async throws {
    if let chezmoi {
      if reportReviewedApplyStep {
        phase = .applyingReviewedPull(String(localized: "Checking dotfile changes"))
      }
      try Task.checkCancellation()
      // Three-way merge text dotfiles via the user's configured
      // `merge.command` before falling back to `apply`. Binaries /
      // plists keep the apply path because chezmoi merge doesn't
      // handle them.
      let status = (try? await chezmoi.status(cwd: nil)) ?? ""
      for target in Self.textMergeTargets(fromStatus: status) {
        try Task.checkCancellation()
        do {
          if reportReviewedApplyStep {
            phase = .applyingReviewedPull(String(localized: "Merging \(target)"))
          }
          try await chezmoi.merge(target: target, cwd: nil)
        } catch {
          SojournLog.sync.error(
            "merge failed for \(target, privacy: .public): \(String(describing: error), privacy: .public)"
          )
        }
      }
      if reportReviewedApplyStep {
        phase = .applyingReviewedPull(String(localized: "Applying dotfiles"))
      }
      try Task.checkCancellation()
      try await chezmoi.apply(dryRun: false, cwd: nil)
    }

    for brewfile in brewfileCandidates() {
      if reportReviewedApplyStep {
        phase = .applyingReviewedPull(String(localized: "Installing \(brewfile.lastPathComponent)"))
      }
      try Task.checkCancellation()
      _ = try await brewBundle.install(file: brewfile, upgrade: false, cleanup: false)
    }
  }

  private func pullApplyReview() async throws -> PullApplyReview {
    let task = Task.detached(priority: .userInitiated) { [repoURL, cooldown] in
      try await Self.pullApplyReview(repoURL: repoURL, cooldown: cooldown)
    }
    return try await withTaskCancellationHandler {
      try await task.value
    } onCancel: {
      task.cancel()
    }
  }

  private nonisolated static func pullApplyReview(
    repoURL: URL,
    cooldown: CooldownGate
  ) async throws -> PullApplyReview {
    var packageReviews: [PullPackageReview] = []
    var omittedPackages = 0
    for brewfile in brewfileCandidates(repoURL: repoURL) {
      try Task.checkCancellation()
      guard let text = try? String(contentsOf: brewfile, encoding: .utf8) else {
        continue
      }
      let ast = BrewfileParser.parse(text)
      let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
      for (lineNumber, entry) in ast.entries.enumerated() {
        try Task.checkCancellation()
        guard let package = entry.packageID else {
          if let rawRuby = brewfileRubyReview(
            line: lines.indices.contains(lineNumber) ? lines[lineNumber] : "",
            lineNumber: lineNumber + 1,
            brewfile: brewfile.lastPathComponent
          ) {
            if packageReviews.count < PullApplyReview.previewLimit {
              packageReviews.append(rawRuby)
            } else {
              omittedPackages += 1
            }
          }
          continue
        }
        let manager = Self.managerID(for: entry)
        let decision = await cooldown.evaluate(
          package: package,
          manager: manager,
          ecosystem: Self.osvEcosystem(for: manager),
          installedVersion: nil,
          candidateVersion: nil,
          releasedAt: nil
        )
        if packageReviews.count < PullApplyReview.previewLimit {
          packageReviews.append(PullPackageReview(
            brewfile: brewfile.lastPathComponent,
            manager: manager,
            package: package,
            reason: Self.pullApplyReviewReason(for: entry, manager: manager, decision: decision)
          ))
        } else {
          omittedPackages += 1
        }
      }
    }
    let allScripts = try Self.chezmoiScriptPaths(under: repoURL)
    let allTemplates = try Self.chezmoiTemplatePaths(under: repoURL)
    let shownScripts = Array(allScripts.prefix(PullApplyReview.previewLimit))
    let shownTemplates = Array(allTemplates.prefix(PullApplyReview.previewLimit))
    return PullApplyReview(
      chezmoiScripts: shownScripts,
      chezmoiTemplates: shownTemplates,
      packageReviews: packageReviews,
      omittedChezmoiScriptCount: max(0, allScripts.count - shownScripts.count),
      omittedChezmoiTemplateCount: max(0, allTemplates.count - shownTemplates.count),
      omittedPackageReviewCount: omittedPackages,
      contentFingerprint: Self.pullApplyFingerprint(
        repoURL: repoURL,
        brewfiles: brewfileCandidates(repoURL: repoURL),
        scripts: allScripts + allTemplates
      )
    )
  }

  private nonisolated static func brewfileRubyReview(
    line: String,
    lineNumber: Int,
    brewfile: String
  ) -> PullPackageReview? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { return nil }
    return PullPackageReview(
      brewfile: brewfile,
      manager: "ruby",
      package: "line \(lineNumber)",
      reason: "Brewfiles are evaluated as Ruby by Homebrew; this unparsed line must be reviewed before brew bundle install."
    )
  }

  private nonisolated static func pullApplyFingerprint(
    repoURL: URL,
    brewfiles: [URL],
    scripts: [String]
  ) -> String {
    var hasher = SHA256()
    for brewfile in brewfiles.sorted(by: { $0.path < $1.path }) {
      update(&hasher, string: "brewfile:\(brewfile.lastPathComponent)\n")
      if let data = try? Data(contentsOf: brewfile) {
        hasher.update(data: data)
      }
      update(&hasher, string: "\n")
    }
    for script in scripts.sorted() {
      update(&hasher, string: "script:\(script)\n")
      let url = repoURL.appendingPathComponent(script)
      if let data = try? Data(contentsOf: url) {
        hasher.update(data: data)
      }
      update(&hasher, string: "\n")
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }

  private nonisolated static func update(_ hasher: inout SHA256, string: String) {
    hasher.update(data: Data(string.utf8))
  }

  private func brewfileCandidates() -> [URL] {
    Self.brewfileCandidates(repoURL: repoURL)
  }

  private nonisolated static func brewfileCandidates(repoURL: URL) -> [URL] {
    let host = Self.hostname()
    return [
      repoURL.appendingPathComponent("Brewfile.common"),
      repoURL.appendingPathComponent("Brewfile.\(host)")
    ].filter { FileManager.default.fileExists(atPath: $0.path) }
  }

  internal nonisolated static func chezmoiScriptPaths(under root: URL) throws -> [String] {
    try chezmoiReviewPaths(under: root) { url in
      let name = url.lastPathComponent
      return name.hasPrefix("run_")
        || name.hasPrefix("run_once_")
        || name.hasPrefix("run_onchange_")
    }
  }

  internal nonisolated static func chezmoiTemplatePaths(under root: URL) throws -> [String] {
    try chezmoiReviewPaths(under: root) { url in
      url.lastPathComponent.hasSuffix(".tmpl")
        || url.pathComponents.contains(".chezmoitemplates")
    }
  }

  private nonisolated static func chezmoiReviewPaths(
    under root: URL,
    matching shouldInclude: (URL) -> Bool
  ) throws -> [String] {
    let rootPath = root.resolvingSymlinksInPath().path
    guard let enumerator = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: []
    ) else {
      return []
    }
    var paths: [String] = []
    for case let url as URL in enumerator {
      try Task.checkCancellation()
      if url.pathComponents.contains(".git") {
        enumerator.skipDescendants()
        continue
      }
      guard shouldInclude(url) else {
        continue
      }
      let urlPath = url.resolvingSymlinksInPath().path
      let rel = urlPath.hasPrefix(rootPath + "/")
        ? String(urlPath.dropFirst(rootPath.count + 1))
        : url.lastPathComponent
      paths.append(rel)
    }
    return paths.sorted()
  }

  private nonisolated static func managerID(for entry: BrewfileEntry) -> String {
    switch entry {
    case .tap:     return "tap"
    case .brew:    return "brew"
    case .cask:    return "cask"
    case .mas:     return "mas"
    case .vscode:  return "vscode"
    case .go:      return "go"
    case .cargo:   return "cargo"
    case .uv:      return "uv"
    case .krew:    return "krew"
    case .npm:     return "npm"
    case .flatpak: return "flatpak"
    case .comment, .blank:
      return "unknown"
    }
  }

  private nonisolated static func pullApplyReviewReason(
    for entry: BrewfileEntry,
    manager: String,
    decision: CooldownDecision
  ) -> String {
    let base: String
    switch entry {
    case .tap:
      base = "Tap changes package source trust and must be reviewed before brew bundle install."
    case .brew, .cask:
      base = "Homebrew entries can run install or postinstall steps and must be reviewed after pull."
    case .mas:
      base = "MAS entries can install App Store software and must be reviewed after pull."
    case .vscode, .go, .cargo, .uv, .krew, .npm, .flatpak:
      base = "\(manager) entries can install executable tools and must be reviewed after pull."
    case .comment, .blank:
      base = "Metadata entry."
    }

    if decision.reason == "cooldown disabled in settings" {
      return "\(base) Cooldown is disabled, but pull-apply consent still applies."
    }
    if decision.requiresPrompt || !decision.allowAuto {
      return "\(base) Current policy: \(decision.reason)."
    }
    return base
  }

  private nonisolated static func osvEcosystem(for manager: String) -> String? {
    switch manager {
    case "brew", "cask": return "Homebrew"
    case "npm":          return "npm"
    case "cargo":        return "crates.io"
    case "go":           return "Go"
    default:             return nil
    }
  }

  // MARK: - Hostname

  private nonisolated static func hostname() -> String {
    if let env = ProcessInfo.processInfo.environment["HOST"], !env.isEmpty {
      return env
    }
    var buffer = [UInt8](repeating: 0, count: 256)
    let ok = buffer.withUnsafeMutableBufferPointer { ptr -> Bool in
      ptr.baseAddress!.withMemoryRebound(to: CChar.self, capacity: ptr.count) { cptr in
        gethostname(cptr, ptr.count) == 0
      }
    }
    if ok {
      let nullIndex = buffer.firstIndex(of: 0) ?? buffer.count
      let host = String(decoding: buffer[..<nullIndex], as: UTF8.self)
      if let dot = host.firstIndex(of: ".") {
        return String(host[..<dot])
      }
      return host
    }
    return "unknown-host"
  }

  // MARK: - Status parsing

  /// Extensions chezmoi cannot mergefully (binary/plist) — these paths
  /// stay in the `apply` path. Everything else is treated as text.
  internal nonisolated static let nonMergeableExtensions: Set<String> = [
    "plist", "png", "jpg", "jpeg", "gif", "tiff", "bmp", "icns", "heic",
    "pdf", "zip", "tar", "gz", "bz2", "xz", "7z",
    "dmg", "pkg",
    "so", "dylib", "a", "o",
    "bin", "exe", "app", "car",
    "sqlite", "db", "ico", "woff", "woff2", "ttf", "otf"
  ]

  /// Parse `chezmoi status` output into the subset of modified targets
  /// suitable for `chezmoi merge`.
  ///
  /// chezmoi status format: 2-char status code, space, target path. The
  /// first column is source state, second is target state. Either being
  /// `M` (modified) means a merge is potentially useful.
  internal nonisolated static func textMergeTargets(fromStatus status: String) -> [String] {
    var out: [String] = []
    for raw in status.split(separator: "\n") {
      let line = String(raw)
      guard line.count > 3 else { continue }
      let prefix = line.prefix(2)
      let path = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
      guard !path.isEmpty else { continue }
      guard prefix.contains("M") else { continue }
      let ext = (path as NSString).pathExtension.lowercased()
      if nonMergeableExtensions.contains(ext) { continue }
      out.append(path)
    }
    return out
  }

  // MARK: - Cooldown gate

  internal func evaluateCooldown(
    package: String,
    manager: String,
    ecosystem: String?,
    installedVersion: String?,
    candidateVersion: String?,
    releasedAt: Date?
  ) async -> CooldownDecision {
    await cooldown.evaluate(
      package: package,
      manager: manager,
      ecosystem: ecosystem,
      installedVersion: installedVersion,
      candidateVersion: candidateVersion,
      releasedAt: releasedAt
    )
  }
}
