import Foundation
import Observation

/// Owns Task lifecycle for subprocess invocations. Pipes into LogBuffer.
/// UI dispatches intents here instead of creating Tasks directly.
/// See docs/ARCHITECTURE.md section 11.
@MainActor
@Observable
final class JobRunner {
  var activeJobs: [JobID: Job] = [:]

  init() {}
}

typealias JobID = UUID

/// Lifecycle record for one subprocess invocation.
struct Job: Sendable, Identifiable {
  let id: JobID
  let command: String
  let arguments: [String]
  let startedAt: Date
  var endedAt: Date?
  var exitCode: Int32?
  var status: Status

  enum Status: Sendable, Equatable {
    case running
    case succeeded
    case failed(String)
    case cancelled
  }
}
