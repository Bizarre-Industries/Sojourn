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
        // Audit §2.2.3 — three-way merge text dotfiles via the user's
        // configured `merge.command` before falling back to `apply`.
        // Binaries / plists keep the apply path because chezmoi merge
        // doesn't handle them.
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
  /// suitable for `chezmoi merge`. Audit §2.2.3.
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
