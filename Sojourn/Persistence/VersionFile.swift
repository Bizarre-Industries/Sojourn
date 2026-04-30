// Sojourn — VersionFile
//
// Audit §3.3.2. Both `~/Library/Application Support/Sojourn/version.toml`
// (app-side) and `<repo>/.sojourn/version.toml` (repo-side) decode to
// this type. The migration coordinator (Stage 9) compares
// `schema_version` / `repo_format_version` and runs the right
// migrations before any other I/O.
//
// File format is plain TOML on disk per `docs/reference/file-formats/`.
// Today we serialize via `JSONEncoder` for ergonomics; Stage 11 wires
// canonical TOML round-trip via `SojournFileCodec`.

import Foundation

internal struct VersionFile: Sendable, Hashable, Codable {
  internal let appVersion: String          // semver, e.g. "0.1.0"
  internal let schemaVersion: Int          // local persistence layout
  internal let repoFormatVersion: Int      // repo file format
  internal let lastWriter: String?         // machine name of last push
  internal let updatedAt: Date

  internal init(
    appVersion: String,
    schemaVersion: Int = 1,
    repoFormatVersion: Int = 1,
    lastWriter: String? = nil,
    updatedAt: Date = Date()
  ) {
    self.appVersion = appVersion
    self.schemaVersion = schemaVersion
    self.repoFormatVersion = repoFormatVersion
    self.lastWriter = lastWriter
    self.updatedAt = updatedAt
  }

  // MARK: - Persisted JSON shadow (Stage 11 swaps to TOML)

  internal static func load(from url: URL) throws -> VersionFile? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(VersionFile.self, from: data)
  }

  internal func save(to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    try data.write(to: url, options: .atomic)
  }
}

// MARK: - Migration plan

internal struct MigrationPlan: Sendable, Hashable {
  internal let from: VersionFile
  internal let to: VersionFile
  internal let steps: [String]
  internal let snapshotRequired: Bool
}
