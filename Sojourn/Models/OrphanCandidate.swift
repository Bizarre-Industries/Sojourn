// Sojourn — OrphanCandidate
//
// A file or directory in `~/Library/**` (or `~/.*`) that may be
// orphan-able because its owning app is no longer installed. Classified
// safe/review/risky by CleanupService (Phase 5). Never `rm`-d: the user
// moves via NSFileManager.trashItem through DeletionsDB. See
// docs/ARCHITECTURE.md §10.

import Foundation

internal struct OrphanCandidate: Sendable, Hashable, Identifiable {
  internal var id: URL { path }
  internal let path: URL
  internal let bundleID: String?
  internal let category: Category
  internal let sizeBytes: Int64
  internal let lastModifiedAt: Date?
  internal let reason: String

  internal enum Category: String, Sendable, Codable, Hashable {
    case safe    // Cache dirs, deterministic to recreate.
    case review  // Application Support, HTTPStorages — user may want.
    case risky   // Preferences, Saved Application State — may hold keys.
  }

  internal init(
    path: URL,
    bundleID: String? = nil,
    category: Category,
    sizeBytes: Int64 = 0,
    lastModifiedAt: Date? = nil,
    reason: String
  ) {
    self.path = path
    self.bundleID = bundleID
    self.category = category
    self.sizeBytes = sizeBytes
    self.lastModifiedAt = lastModifiedAt
    self.reason = reason
  }
}
