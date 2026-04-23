// Sojourn — Conflict
//
// A single file-level conflict surfaced by SyncCoordinator during pull
// (remote → local). Resolved in the UI via ConflictResolutionView (Phase 6)
// three-way-diff style. See docs/ARCHITECTURE.md §6.

import Foundation

internal struct Conflict: Sendable, Hashable, Identifiable {
  internal let id: UUID
  internal let path: String
  internal let kind: Kind
  internal let localContent: String?
  internal let remoteContent: String?
  internal let ancestorContent: String?
  internal var resolution: Resolution

  internal enum Kind: String, Sendable, Codable, Hashable {
    case textEdit
    case binary
    case delete
    case rename
    case packagesToml = "packages.toml"
    case chezmoiTemplate
    case plist
  }

  internal enum Resolution: Sendable, Hashable {
    case unresolved
    case keepLocal
    case keepRemote
    case manualMerge(String)
  }

  internal init(
    id: UUID = UUID(),
    path: String,
    kind: Kind,
    localContent: String? = nil,
    remoteContent: String? = nil,
    ancestorContent: String? = nil,
    resolution: Resolution = .unresolved
  ) {
    self.id = id
    self.path = path
    self.kind = kind
    self.localContent = localContent
    self.remoteContent = remoteContent
    self.ancestorContent = ancestorContent
    self.resolution = resolution
  }
}
