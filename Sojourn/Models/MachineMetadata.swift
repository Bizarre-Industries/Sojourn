// Sojourn — MachineMetadata
//
// Per-Mac identity + override map. Stored in the sync repo at
// `.sojourn/machines/<hostname>.toml`; Sojourn uses chezmoi's Go template
// engine to conditionally render per-machine variants. See
// docs/ARCHITECTURE.md §6 and §15.

import Foundation

internal struct MachineMetadata: Sendable, Codable, Hashable, Identifiable {
  internal let id: UUID
  internal let hostname: String
  internal let firstSeenAt: Date
  internal var lastSeenAt: Date
  internal var overrides: [String: String]

  internal init(
    id: UUID = UUID(),
    hostname: String = MachineMetadata.currentHostname(),
    firstSeenAt: Date = Date(),
    lastSeenAt: Date = Date(),
    overrides: [String: String] = [:]
  ) {
    self.id = id
    self.hostname = hostname
    self.firstSeenAt = firstSeenAt
    self.lastSeenAt = lastSeenAt
    self.overrides = overrides
  }

  internal static func currentHostname() -> String {
    Host.current().localizedName
      ?? ProcessInfo.processInfo.hostName
  }
}
