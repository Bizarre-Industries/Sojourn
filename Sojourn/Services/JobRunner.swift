// Sojourn — JobRunner
//
// `@MainActor @Observable` conductor that owns every in-flight `Job`. UI
// views bind to `jobs` directly; service actors dispatch work here rather
// than spawning subprocesses themselves. See docs/ARCHITECTURE.md §11.
//
// v0.3 (v0.3-plan.md "Hard decisions"): per-`JobKind` timeout policy.
// install/upgrade jobs are timeout-exempt (cancellable only); advisory
// /list/dump jobs hard-cap at 30s; snapshot create/restore caps at
// 600s. Explicit `JobRequest.timeout` overrides the kind default
// (callers can shorten an advisory job to 5s for `--version` probes).

import Foundation
import Observation

/// Job classification driving the per-tier timeout policy locked in
/// `docs/process/plans/v0.3-plan.md` §"Hard decisions".
internal enum JobKind: String, Sendable, Codable, CaseIterable {
  /// `brew bundle install`, `brew bundle upgrade`, `mas install` —
  /// long-running, user-invoked, network-bound. Timeout-exempt;
  /// cancellable only via `JobRunner.cancel(_:)`.
  case installUpgrade
  /// `brew vulns`, `brew bundle dump`, `chezmoi data`, `<tool>
  /// --version` — short-running. Hard cap 30s.
  case advisory
  /// Snapshot create/restore (tarball write/extract). Hard cap 600s.
  case snapshot

  /// Hard wall-clock cap for this tier. nil means timeout-exempt.
  internal var hardTimeout: TimeInterval? {
    switch self {
    case .installUpgrade: return nil
    case .advisory:       return 30
    case .snapshot:       return 600
    }
  }
}

internal struct JobRequest: Sendable {
  internal let label: String
  internal let tool: URL
  internal let args: [String]
  internal let env: [String: String]?
  internal let cwd: URL?
  /// Explicit per-call timeout. Overrides `kind.hardTimeout` when set.
  /// Existing callers (pre-v0.3) that pass `timeout: 60` keep working;
  /// callers that omit it pick up the kind's default.
  internal let timeout: TimeInterval?
  /// Job tier driving default timeout policy. Defaults to `.advisory`
  /// — the safer default for new callers; long-running install/upgrade
  /// jobs MUST opt into `.installUpgrade` explicitly.
  internal let kind: JobKind

  internal init(
    label: String,
    tool: URL,
    args: [String] = [],
    env: [String: String]? = nil,
    cwd: URL? = nil,
    timeout: TimeInterval? = nil,
    kind: JobKind = .advisory
  ) {
    self.label = label
    self.tool = tool
    self.args = args
    self.env = env
    self.cwd = cwd
    self.timeout = timeout
    self.kind = kind
  }

  /// Effective timeout = explicit override OR kind default. nil → no cap.
  internal var effectiveTimeout: TimeInterval? {
    timeout ?? kind.hardTimeout
  }
}

internal struct JobHandle: Sendable {
  internal let id: JobID
  internal let bufferID: LogBufferID
}

@Observable
@MainActor
internal final class JobRunner {
  internal private(set) var jobs: [Job] = []
  internal private(set) var buffers: [LogBufferID: LogBuffer] = [:]

  private let runner: SubprocessRunner
  private var tasks: [JobID: Task<Void, Never>] = [:]

  internal init(runner: SubprocessRunner) {
    self.runner = runner
  }

  @discardableResult
  internal func submit(_ request: JobRequest) -> JobHandle {
    let buffer = LogBuffer()
    let bufferID = buffer.id
    let job = Job(
      label: request.label,
      tool: request.tool,
      args: request.args,
      state: .pending,
      logBufferID: bufferID
    )
    jobs.append(job)
    buffers[bufferID] = buffer
    let jobID = job.id

    let task = Task.detached { [weak self, runner] in
      await self?.markRunning(jobID)
      let stream = runner.stream(
        tool: request.tool,
        args: request.args,
        env: request.env,
        cwd: request.cwd
      )
      do {
        for try await chunk in stream {
          await buffer.feed(chunk)
        }
        await buffer.close()
        await self?.markSucceeded(jobID, exitCode: 0)
      } catch let SubprocessError.nonZeroExit(code, _, _) {
        await buffer.close()
        await self?.markSucceeded(jobID, exitCode: code, asFailure: true)
      } catch SubprocessError.cancelled {
        await buffer.close()
        await self?.markCancelled(jobID)
      } catch {
        await buffer.close()
        await self?.markFailed(jobID, reason: "\(error)")
      }
    }
    tasks[jobID] = task

    // Per-tier timeout watchdog. installUpgrade kind has nil
    // effectiveTimeout → no watchdog (cancellable only via cancel()).
    if let timeout = request.effectiveTimeout {
      Task.detached { [weak self] in
        try? await Task.sleep(for: .seconds(timeout))
        await self?.markTimedOut(jobID, after: timeout)
      }
    }

    return JobHandle(id: jobID, bufferID: bufferID)
  }

  internal func cancel(_ jobID: JobID) {
    tasks[jobID]?.cancel()
  }

  internal func cancelAll() {
    for task in tasks.values { task.cancel() }
  }

  internal func job(_ jobID: JobID) -> Job? {
    jobs.first(where: { $0.id == jobID })
  }

  internal func buffer(_ bufferID: LogBufferID) -> LogBuffer? {
    buffers[bufferID]
  }

  internal func purgeTerminal() {
    let terminalIDs = Set(jobs.filter { $0.state.isTerminal }.map(\.id))
    jobs.removeAll { terminalIDs.contains($0.id) }
    for id in terminalIDs { tasks.removeValue(forKey: id) }
  }

  // MARK: - State transitions

  /// Locate a non-terminal job by id. Terminal-state jobs cannot
  /// transition again (timeout watchdog races against natural
  /// completion — first finalizer wins).
  private func nonTerminalIndex(of id: JobID) -> Int? {
    guard let idx = jobs.firstIndex(where: { $0.id == id }) else { return nil }
    return jobs[idx].state.isTerminal ? nil : idx
  }

  private func markRunning(_ id: JobID) {
    guard let idx = nonTerminalIndex(of: id) else { return }
    jobs[idx].state = .running
    jobs[idx].startedAt = Date()
  }

  private func markSucceeded(_ id: JobID, exitCode: Int32, asFailure: Bool = false) {
    guard let idx = nonTerminalIndex(of: id) else { return }
    jobs[idx].state = asFailure
      ? .failed(reason: "non-zero exit \(exitCode)")
      : .succeeded(exitCode: exitCode)
    jobs[idx].finishedAt = Date()
  }

  private func markFailed(_ id: JobID, reason: String) {
    guard let idx = nonTerminalIndex(of: id) else { return }
    jobs[idx].state = .failed(reason: reason)
    jobs[idx].finishedAt = Date()
  }

  private func markCancelled(_ id: JobID) {
    guard let idx = nonTerminalIndex(of: id) else { return }
    jobs[idx].state = .cancelled
    jobs[idx].finishedAt = Date()
  }

  /// Watchdog finalizer — called when the per-kind hard timeout
  /// elapses. Marks the job failed with a "timed out" reason and
  /// cancels its work task. No-op if the job already finished
  /// naturally (terminal-state guard).
  private func markTimedOut(_ id: JobID, after seconds: TimeInterval) {
    guard let idx = nonTerminalIndex(of: id) else { return }
    jobs[idx].state = .failed(reason: "timed out after \(Int(seconds))s")
    jobs[idx].finishedAt = Date()
    tasks[id]?.cancel()
  }
}
