// Sojourn — PreferenceDomain
//
// Per-app plist domain metadata. Populated from
// `Sojourn/Resources/data/applications/*.toml` (Phase 5) and referenced by
// PrefService for `defaults export/import`. See docs/ARCHITECTURE.md §8
// (plist app preference sync strategy).

import Foundation

internal struct PreferenceDomain: Sendable, Codable, Hashable, Identifiable {
  internal var id: String { bundleID }
  internal let bundleID: String
  internal let domain: String
  internal let layer: Layer
  internal let syncable: Bool
  internal let displayName: String?

  internal enum Layer: String, Sendable, Codable, Hashable {
    case user
    case system
    case sandboxed
    case appleInternal = "apple-internal"
  }

  internal init(
    bundleID: String,
    domain: String,
    layer: Layer,
    syncable: Bool = true,
    displayName: String? = nil
  ) {
    self.bundleID = bundleID
    self.domain = domain
    self.layer = layer
    self.syncable = syncable
    self.displayName = displayName
  }
}
