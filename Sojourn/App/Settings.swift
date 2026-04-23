import Foundation

/// Persisted user settings. See docs/ARCHITECTURE.md section 11.
struct Settings: Codable, Sendable, Equatable {
  var toolLocations: [String: String]
  var cooldownDays: Int
  var gitRemoteURL: String?
  var machineID: UUID

  init(
    toolLocations: [String: String] = [:],
    cooldownDays: Int = 7,
    gitRemoteURL: String? = nil,
    machineID: UUID = UUID()
  ) {
    self.toolLocations = toolLocations
    self.cooldownDays = cooldownDays
    self.gitRemoteURL = gitRemoteURL
    self.machineID = machineID
  }
}
