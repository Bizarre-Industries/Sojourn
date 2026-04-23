// Sojourn — DotfileOwner
//
// Mapping from a dotfile path (relative to $HOME) to the tool/manager
// that owns it. Populated from
// `Sojourn/Resources/data/dotfile_owners.toml` (Phase 5) plus runtime
// augmentation from chezmoi/mpm output. Used by CleanupService to classify
// orphan candidates. See docs/ARCHITECTURE.md §10.

import Foundation

internal struct DotfileOwner: Sendable, Codable, Hashable, Identifiable {
  internal var id: String { path }
  internal let path: String
  internal let owner: Owner
  internal let manager: String?
  internal let notes: String?

  internal enum Owner: String, Sendable, Codable, Hashable {
    case chezmoi
    case mpm
    case user
    case system
    case thirdParty = "third-party"
    case unknown
  }

  internal init(
    path: String,
    owner: Owner,
    manager: String? = nil,
    notes: String? = nil
  ) {
    self.path = path
    self.owner = owner
    self.manager = manager
    self.notes = notes
  }
}
