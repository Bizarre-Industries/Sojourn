// Sojourn — SyncCoordinator
//
// Orchestrates push (local → remote) and pull (remote → local) against the
// user's data repo. See docs/ARCHITECTURE.md §6. Pull must complete +
// resolve any conflicts before push is allowed. Pre-op snapshot on every
// destructive step.

import Foundation
import Observation

internal enum SyncPhase: Sendable, Equatable {
  case idle
  case pulling
  case resolvingConflicts([Conflict])
  case scanningSecrets
  case pushing
  case done(HistoryEntry.Kind)
  case failed(String)
}

@Observable
@MainActor
internal final class SyncCoordinator {
  internal private(set) var phase: SyncPhase = .idle

  private let repoURL: URL
  private let git: GitService
  private let chezmoi: ChezmoiService?
  private let mpm: MPMService?
  private let pref: PrefService?
  private let secrets: SecretScanService?
  private let snapshots: SnapshotService
  private let cooldown: CooldownGate

  internal init(
    repoURL: URL,
    git: GitService,
    chezmoi: ChezmoiService?,
    mpm: MPMService?,
    pref: PrefService?,
    secrets: SecretScanService?,
    snapshots: SnapshotService,
    cooldown: CooldownGate
  ) {
    self.repoURL = repoURL
    self.git = git
    self.chezmoi = chezmoi
    self.mpm = mpm
    self.pref = pref
    self.secrets = secrets
    self.snapshots = snapshots
    self.cooldown = cooldown
  }

  // MARK: - Pull

  internal func pull(branch: String = "main") async {
    let signpost = SojournSignpost.sync
    let state = signpost.beginInterval("pull", id: signpost.makeSignpostID())
    SojournLog.sync.info("pull start branch=\(branch, privacy: .public)")

    phase = .pulling
    do {
      _ = try await snapshots.capture(operation: .syncPull, sources: [repoURL])
      try await git.pull(remote: "origin", branch: branch, cwd: repoURL)
      if let chezmoi {
        try await chezmoi.apply(dryRun: false, cwd: nil)
      }
      if let mpm {
        let packages = repoURL.appendingPathComponent("packages.toml")
        if FileManager.default.fileExists(atPath: packages.path) {
          try await mpm.restore(from: packages)
        }
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
    let signpost = SojournSignpost.sync
    let state = signpost.beginInterval("push", id: signpost.makeSignpostID())
    defer { signpost.endInterval("push", state) }
    SojournLog.sync.info("push start branch=\(branch, privacy: .public)")

    phase = .scanningSecrets
    if let secrets {
      do {
        let findings = try await secrets.scanStaged(cwd: repoURL)
        let highConfidence = findings.filter(\.isHighConfidence)
        if !highConfidence.isEmpty {
          SojournLog.secrets.error(
            "blocked push: \(highConfidence.count) high-confidence finding(s)"
          )
          phase = .failed(
            "\(highConfidence.count) high-confidence secret(s) — resolve via SecretFindingsModal"
          )
          return
        }
      } catch {
        SojournLog.secrets.error("gitleaks failed: \(String(describing: error), privacy: .public)")
        phase = .failed("gitleaks failed: \(error)")
        return
      }
    }

    phase = .pushing
    do {
      _ = try await snapshots.capture(operation: .syncPush, sources: [repoURL])

      let syncFiles = ["packages.toml", "dotfiles", "prefs", ".sojourn"]
      let stageable = syncFiles
        .map { repoURL.appendingPathComponent($0) }
        .filter { FileManager.default.fileExists(atPath: $0.path) }
        .map { $0.lastPathComponent }
      if !stageable.isEmpty {
        try await git.add(paths: stageable, cwd: repoURL)
        _ = try await git.commit(message: message, signoff: true, cwd: repoURL)
      }
      try await git.push(remote: "origin", branch: branch, cwd: repoURL)
      phase = .done(.syncPush)
    } catch {
      phase = .failed("push failed: \(error)")
    }
  }

  internal func reset() {
    phase = .idle
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
