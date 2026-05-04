// Sojourn — ConflictResolver
//
// Refuse-and-show-diff state machine for multi-machine sync. Owns the
// "remote moved while we were offline" surface extracted from
// `SyncCoordinator.pull` per ADR-0026. The cooperative writer lock at
// `.sojourn/active.toml` (ADR-0012) is defeatable when one Mac is offline
// while another acquires; this resolver is the load-bearing safety: a
// pull must complete cleanly before push is allowed.
//
// State machine:
//   .clean             — nothing inbound; sync proceeds normally
//   .detecting         — `git fetch` + `aheadBehind` in flight
//   .conflictPending(commits) — UI surfaces modal; user picks
//   .resolving(choice) — `git pull --rebase` / `--no-rebase` running
//   .resolved          — clean state; sync proceeds
//   .blockedFromPush   — push refused until pull completes
//   .failed(reason)    — git error surfaced to UI
//
// Refs: ADR-0026 (multi-machine conflict UX);
//       docs/process/plans/v0.3-plan.md stage 5.

import Foundation
import Observation

@Observable
@MainActor
internal final class ConflictResolver {
  internal enum Choice: Sendable, Equatable {
    case rebase
    case merge
    case abort
  }

  internal enum State: Sendable, Equatable {
    case clean
    case detecting
    case conflictPending([InboundCommit])
    case resolving(Choice)
    case resolved
    case blockedFromPush(reason: String)
    case failed(String)
  }

  internal private(set) var state: State = .clean

  private let git: GitService
  private let repoURL: URL

  internal init(git: GitService, repoURL: URL) {
    self.git = git
    self.repoURL = repoURL
  }

  /// Detect whether the remote has commits not present locally. Sets
  /// state to `.clean` or `.conflictPending([InboundCommit])`. Failure
  /// at fetch or aheadBehind sets `.failed(...)`. Idempotent during
  /// `.detecting` (council 2026-05-04 stage5 architect condition).
  internal func detect(branch: String = "main") async {
    if state == .detecting { return }
    state = .detecting
    do {
      try await git.fetch(remote: "origin", cwd: repoURL)
      let ab = try await git.aheadBehind(
        upstream: "origin/\(branch)",
        cwd: repoURL
      )
      if ab.behind <= 0 {
        state = .clean
        return
      }
      let commits = try await git.inboundCommits(
        since: "HEAD",
        upstream: "origin/\(branch)",
        cwd: repoURL,
        limit: 200
      )
      state = .conflictPending(commits)
    } catch {
      state = .failed("detect failed: \(error)")
    }
  }

  /// Apply the user's resolution choice. On `.rebase` or `.merge` runs
  /// the corresponding git pull; on `.abort` leaves local state
  /// untouched but transitions to `.blockedFromPush` so the SyncPane
  /// keeps surfacing the situation until the user pulls.
  internal func apply(_ choice: Choice, branch: String = "main") async {
    state = .resolving(choice)
    do {
      switch choice {
      case .rebase:
        try await git.pullRebase(remote: "origin", branch: branch, cwd: repoURL)
        state = .resolved
      case .merge:
        try await git.pullMerge(remote: "origin", branch: branch, cwd: repoURL)
        state = .resolved
      case .abort:
        state = .blockedFromPush(
          reason: "Pull cancelled. Push blocked until inbound commits are pulled."
        )
      }
    } catch {
      // Council 2026-05-04 stage5 architect condition: clean up the
      // partial-rebase / partial-merge state so the user is not stuck
      // in detached HEAD. Best-effort; ignore secondary errors.
      switch choice {
      case .rebase: try? await git.rebaseAbort(cwd: repoURL)
      case .merge:  try? await git.mergeAbort(cwd: repoURL)
      case .abort:  break
      }
      state = .failed("apply \(choice) failed: \(error). Working tree restored.")
    }
  }

  /// Whether `SyncCoordinator.push` may proceed. False whenever the
  /// resolver knows about unresolved inbound work.
  internal var canPush: Bool {
    switch state {
    case .clean, .resolved: return true
    case .detecting, .conflictPending, .resolving, .blockedFromPush, .failed: return false
    }
  }

  /// Push-blocked diagnostic string for the UI. Empty when canPush.
  internal var pushBlockedReason: String {
    switch state {
    case .conflictPending(let commits):
      return "Push blocked. Pull \(commits.count) commits first or cancel the pull-pending state in Sync."
    case .blockedFromPush(let reason):
      return reason
    case .detecting:
      return "Push blocked. Conflict detection in progress."
    case .resolving(let choice):
      return "Push blocked. \(label(for: choice)) in progress."
    case .failed(let msg):
      return "Push blocked. Last sync error: \(msg)"
    case .clean, .resolved:
      return ""
    }
  }

  /// Inbound commits while in `.conflictPending` state. Returns empty
  /// for any other state.
  internal var pendingCommits: [InboundCommit] {
    if case .conflictPending(let commits) = state { return commits }
    return []
  }

  /// Reset to `.clean`. Call after a successful end-to-end sync cycle
  /// or when the user explicitly resets the resolver state.
  internal func reset() {
    state = .clean
  }

  private nonisolated func label(for choice: Choice) -> String {
    switch choice {
    case .rebase: return "Pull --rebase"
    case .merge:  return "Pull --merge"
    case .abort:  return "Abort"
    }
  }
}
