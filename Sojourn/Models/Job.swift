// Sojourn — Job
//
// Subprocess-execution unit tracked by `JobRunner`. Every external-process
// invocation Sojourn makes flows through a Job so the UI has a stable handle
// to cancel, tail logs, and surface errors. See docs/ARCHITECTURE.md §11.

import Foundation

public struct JobID: Sendable, Hashable, Codable, RawRepresentable {
  public let rawValue: UUID
  public init(rawValue: UUID) { self.rawValue = rawValue }
  public init() { self.rawValue = UUID() }
}

public struct LogBufferID: Sendable, Hashable, Codable, RawRepresentable {
  public let rawValue: UUID
  public init(rawValue: UUID) { self.rawValue = rawValue }
  public init() { self.rawValue = UUID() }
}

public enum JobState: Sendable, Equatable {
  case pending
  case running
  case succeeded(exitCode: Int32)
  case failed(reason: String)
  case cancelled

  public var isTerminal: Bool {
    switch self {
    case .pending, .running: return false
    case .succeeded, .failed, .cancelled: return true
    }
  }
}

public struct Job: Sendable, Identifiable {
  public let id: JobID
  public let label: String
  public let tool: URL
  public let args: [String]
  public var state: JobState
  public var startedAt: Date?
  public var finishedAt: Date?
  public var logBufferID: LogBufferID

  public init(
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

  public var duration: TimeInterval? {
    guard let startedAt, let finishedAt else { return nil }
    return finishedAt.timeIntervalSince(startedAt)
  }
}
