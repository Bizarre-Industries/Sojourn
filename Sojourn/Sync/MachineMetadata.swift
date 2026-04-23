import Foundation

/// Per-machine metadata written to the data repo at .sojourn/machines/<id>.toml.
/// See docs/ARCHITECTURE.md section 6 (Model).
struct MachineMetadata: Sendable, Codable, Equatable {
  let id: UUID
  var hostname: String
  var humanName: String
  var lastPushAt: Date?
  var lastPushCommit: String?
  var ageRecipient: String?
}

/// Cooperative writer lock stored at .sojourn/active.toml.
/// Not authoritative; git has no locking. See section 6 (Take writer lock).
struct ActiveWriter: Sendable, Codable, Equatable {
  var machineID: UUID
  var tookLockAt: Date
  var commitSHA: String
}
