// Sojourn — HistoryEntry
//
// Chronological audit log row. Surfaces in the History pane per
// docs/ARCHITECTURE.md §11. Persisted via Settings; also referenced by
// SyncCoordinator for rollback affordances (Phase 4).

import Foundation

internal struct HistoryEntry: Sendable, Codable, Hashable, Identifiable {
  internal let id: UUID
  internal let kind: Kind
  internal let description: String
  internal let timestamp: Date
  internal let jobID: JobID?
  internal let snapshotPath: String?

  internal enum Kind: String, Sendable, Codable {
    case bootstrap
    case syncPull  = "sync.pull"
    case syncPush  = "sync.push"
    case packageInstall = "package.install"
    case packageRemove  = "package.remove"
    case packageUpgrade = "package.upgrade"
    case dotfileApply   = "dotfile.apply"
    case prefImport     = "pref.import"
    case prefExport     = "pref.export"
    case cleanupTrash   = "cleanup.trash"
    case snapshotCreate = "snapshot.create"
    case rollback
  }

  internal init(
    id: UUID = UUID(),
    kind: Kind,
    description: String,
    timestamp: Date = Date(),
    jobID: JobID? = nil,
    snapshotPath: String? = nil
  ) {
    self.id = id
    self.kind = kind
    self.description = description
    self.timestamp = timestamp
    self.jobID = jobID
    self.snapshotPath = snapshotPath
  }
}
