import Foundation
import Observation

/// Ring-buffered, Observable log of AttributedString rows.
/// Single-consumer AsyncStream inputs fan into this broadcaster.
/// See docs/ARCHITECTURE.md section 11 (Streaming output to UI).
@Observable
@MainActor
final class LogBuffer {
  private(set) var rows: [LogRow] = []
  let capacity: Int

  init(capacity: Int = 5000) {
    self.capacity = capacity
  }
}

struct LogRow: Sendable, Identifiable {
  let id: UUID
  let timestamp: Date
  let attributed: AttributedString
}
