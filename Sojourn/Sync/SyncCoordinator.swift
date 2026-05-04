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

internal enum SyncPhase: Sendable, Equatable {
  case idle
  case pulling
  case resolvingConflicts([Conflict])
  /// Remote has commits not present locally. UI surfaces ConflictResolver
  /// modal listing inbound commits + 3-button choice (rebase / merge /
  /// abort). Per ADR-0026 refuse-and-show-diff state machine.
  case awaitingPullDecision([InboundCommit])
  case scanningSecrets
  case pushing
  case done(HistoryEntry.Kind)
  case failed(String)
}

@Observable
@MainActor
internal final class SyncCoordinator {
  internal private(set) var phase: SyncPhase = .idle

  internal var isOperationActive: Bool {
    switch phase {
    case .pulling, .resolvingConflicts, .scanningSecrets, .pushing:
      return true
    case .idle, .awaitingPullDecision, .done, .failed:
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
      _ = try await snapshots.capture(operation: .syncPull, sources: [repoURL])
      try await git.pull(remote: "origin", branch: branch, cwd: repoURL)
      if let chezmoi {
        // Three-way merge text dotfiles via the user's configured
        // `merge.command` before falling back to `apply`. Binaries /
        // plists keep the apply path because chezmoi merge doesn't
        // handle them.
        let status = (try? await chezmoi.status(cwd: nil)) ?? ""
        for target in Self.textMergeTargets(fromStatus: status) {
          do {
            try await chezmoi.merge(target: target, cwd: nil)
          } catch {
            SojournLog.sync.error(
              "merge failed for \(target, privacy: .public): \(String(describing: error), privacy: .public)"
            )
          }
        }
        try await chezmoi.apply(dryRun: false, cwd: nil)
      }
      // Apply Brewfile.common then Brewfile.<host>. Either may be
      // absent (single-machine setup) — skip silently.
      let host = Self.hostname()
      let candidates = [
        repoURL.appendingPathComponent("Brewfile.common"),
        repoURL.appendingPathComponent("Brewfile.\(host)")
      ].filter { FileManager.default.fileExists(atPath: $0.path) }
      for brewfile in candidates {
        _ = try await brewBundle.install(file: brewfile, upgrade: false, cleanup: false)
      }
      phase = .done(.syncPull)
      SojournLog.sync.info("pull done")
    } catch {
      phase = .failed("pull failed: \(error)")
      SojournLog.sync.error("pull failed: \(String(describing: error), privacy: .public)")
    }
    signpost.endInterval("pull", state)
  }

  // MARK: - Push

  internal func push(branch: String = "main", message: String) async {
    guard !isOperationActive else {
      SojournLog.sync.error("push ignored: sync operation already in progress")
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
