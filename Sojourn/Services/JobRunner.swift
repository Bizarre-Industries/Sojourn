// Sojourn — JobRunner
//
// `@MainActor @Observable` conductor that owns every in-flight `Job`. UI
// views bind to `jobs` directly; service actors dispatch work here rather
// than spawning subprocesses themselves. See docs/ARCHITECTURE.md §11.

import Foundation
import Observation

internal struct JobRequest: Sendable {
  internal let label: String
  internal let tool: URL
  internal let args: [String]
  internal let env: [String: String]?
  internal let cwd: URL?
  internal let timeout: TimeInterval?

  internal init(
    label: String,
    tool: URL,
    args: [String] = [],
    env: [String: String]? = nil,
    cwd: URL? = nil,
    timeout: TimeInterval? = nil
  ) {
    self.label = label
    self.tool = tool
    self.args = args
    self.env = env
    self.cwd = cwd
    self.timeout = timeout
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

  private func markRunning(_ id: JobID) {
    guard let idx = jobs.firstIndex(where: { $0.id == id }) else { return }
    jobs[idx].state = .running
    jobs[idx].startedAt = Date()
  }

  private func markSucceeded(_ id: JobID, exitCode: Int32, asFailure: Bool = false) {
    guard let idx = jobs.firstIndex(where: { $0.id == id }) else { return }
    jobs[idx].state = asFailure
      ? .failed(reason: "non-zero exit \(exitCode)")
      : .succeeded(exitCode: exitCode)
    jobs[idx].finishedAt = Date()
  }

  private func markFailed(_ id: JobID, reason: String) {
    guard let idx = jobs.firstIndex(where: { $0.id == id }) else { return }
    jobs[idx].state = .failed(reason: reason)
    jobs[idx].finishedAt = Date()
  }

  private func markCancelled(_ id: JobID) {
    guard let idx = jobs.firstIndex(where: { $0.id == id }) else { return }
    jobs[idx].state = .cancelled
    jobs[idx].finishedAt = Date()
  }
}
