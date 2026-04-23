// Sojourn — SettingsStore
//
// Persistent user preferences + audit state. Backed by a JSON blob under
// `~/Library/Application Support/Sojourn/config/settings.json`. Keeps
// `UserDefaults` untouched except for small sentinel flags (e.g.,
// onboardingComplete) to avoid polluting `defaults read` output.
// See docs/ARCHITECTURE.md §11.

import Foundation

internal struct Settings: Sendable, Codable, Equatable {
  internal var toolLocations: [ToolResolution] = []
  internal var lastSyncTime: Date? = nil
  internal var cooldownOverrides: [String: AutoUpdateTier] = [:]
  internal var userConsents: [String: Bool] = [:]
  internal var machines: [MachineMetadata] = []
  internal var history: [HistoryEntry] = []
  internal var remoteRepoURL: String? = nil
  internal var cooldownEnabled: Bool = true
  internal var dryRunByDefault: Bool = true

  internal static let empty = Settings()

  internal func tier(for managerID: String) -> AutoUpdateTier {
    cooldownOverrides[managerID] ?? ManagerTier.tier(for: managerID)
  }
}

internal actor SettingsStore {
  private let url: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  internal private(set) var value: Settings

  internal init(
    paths: AppSupportPaths,
    fileManager: FileManager = .default
  ) throws {
    self.url = paths.config.appendingPathComponent("settings.json", isDirectory: false)
    self.fileManager = fileManager

    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    enc.dateEncodingStrategy = .iso8601
    self.encoder = enc

    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    self.decoder = dec

    if fileManager.fileExists(atPath: url.path) {
      let data = try Data(contentsOf: url)
      self.value = (try? decoder.decode(Settings.self, from: data)) ?? Settings.empty
    } else {
      self.value = Settings.empty
      try fileManager.createDirectory(
        at: paths.config, withIntermediateDirectories: true
      )
      try encoder.encode(value).write(to: url, options: .atomic)
    }
  }

  internal func mutate(_ transform: (inout Settings) -> Void) throws {
    transform(&value)
    try save()
  }

  internal func replace(_ new: Settings) throws {
    value = new
    try save()
  }

  private func save() throws {
    let data = try encoder.encode(value)
    try data.write(to: url, options: .atomic)
  }

  internal func resetForTests() throws {
    try replace(.empty)
  }
}
