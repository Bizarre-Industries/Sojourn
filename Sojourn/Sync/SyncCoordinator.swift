import Foundation

/// Orchestrates explicit push/pull. No continuous sync.
/// See docs/ARCHITECTURE.md section 6 for the full spec.
actor SyncCoordinator {
  init() {}
}

enum SyncOperation: Sendable {
  case push
  case pull
  case takeWriterLock
}

/// Pre-operation snapshot written under ~/Library/Application Support/Sojourn/backups/.
/// Enforces the invariant: destructive operations snapshot first (CLAUDE.md rule 5).
struct SyncSnapshot: Sendable, Codable, Equatable {
  let id: UUID
  let operation: String
  let createdAt: Date
  let commitSHA: String?
  let manifestPath: String
}
