// Sojourn — Job
//
// Subprocess-execution unit tracked by `JobRunner`. Every external-process
// invocation Sojourn makes flows through a Job so the UI has a stable handle
// to cancel, tail logs, and surface errors. See docs/ARCHITECTURE.md §11.

import Foundation

internal struct JobID: Sendable, Hashable, Codable, RawRepresentable {
  internal let rawValue: UUID
  internal init(rawValue: UUID) { self.rawValue = rawValue }
  internal init() { self.rawValue = UUID() }
}

internal struct LogBufferID: Sendable, Hashable, Codable, RawRepresentable {
  internal let rawValue: UUID
  internal init(rawValue: UUID) { self.rawValue = rawValue }
  internal init() { self.rawValue = UUID() }
}

internal enum JobState: Sendable, Equatable {
  case pending
  case running
  case succeeded(exitCode: Int32)
  case failed(reason: String)
  case cancelled

  internal var isTerminal: Bool {
    switch self {
    case .pending, .running: return false
    case .succeeded, .failed, .cancelled: return true
    }
  }
}

internal struct Job: Sendable, Identifiable {
  internal let id: JobID
  internal let label: String
  internal let tool: URL
  internal let args: [String]
  internal var state: JobState
  internal var startedAt: Date?
  internal var finishedAt: Date?
  internal var logBufferID: LogBufferID

  internal init(
    id: JobID = JobID(),
    label: String,
    tool: URL,
    args: [String],
    state: JobState = .pending,
    startedAt: Date? = nil,
    finishedAt: Date? = nil,
    logBufferID: LogBufferID = LogBufferID()
  ) {
    self.id = id
    self.label = label
    self.tool = tool
    self.args = args
    self.state = state
    self.startedAt = startedAt
    self.finishedAt = finishedAt
    self.logBufferID = logBufferID
  }

  internal var duration: TimeInterval? {
    guard let startedAt, let finishedAt else { return nil }
    return finishedAt.timeIntervalSince(startedAt)
  }
}
