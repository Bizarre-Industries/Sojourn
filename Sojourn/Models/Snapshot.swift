// Sojourn — Snapshot
//
// Metadata for a pre-op backup stored under
// `~/Library/Application Support/Sojourn/backups/<iso8601>-<op>/`.
// Created by SnapshotService (Phase 4) before every destructive sync or
// apply. 30-day retention, GC'd by BackupsDirectory (Phase 2).
// See docs/ARCHITECTURE.md §6.

import Foundation

internal struct Snapshot: Sendable, Codable, Hashable, Identifiable {
  internal let id: UUID
  internal let operation: HistoryEntry.Kind
  internal let path: URL
  internal let createdAt: Date
  internal let sizeBytes: Int64
  internal let rollbackHint: String?

  internal init(
    id: UUID = UUID(),
    operation: HistoryEntry.Kind,
    path: URL,
    createdAt: Date = Date(),
    sizeBytes: Int64 = 0,
    rollbackHint: String? = nil
  ) {
    self.id = id
    self.operation = operation
    self.path = path
    self.createdAt = createdAt
    self.sizeBytes = sizeBytes
    self.rollbackHint = rollbackHint
  }

  internal var isExpired: Bool {
    let cutoff: TimeInterval = 30 * 24 * 60 * 60
    return Date().timeIntervalSince(createdAt) > cutoff
  }
}
