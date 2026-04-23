// Sojourn — AppSupportPaths
//
// Canonicalizes every on-disk location Sojourn owns under
// `~/Library/Application Support/Sojourn/`. See docs/ARCHITECTURE.md §6
// (snapshots) and §17/§18 (logging, observability).

import Foundation

internal struct AppSupportPaths: Sendable {
  internal static let bundleDirectoryName = "Sojourn"

  internal let root: URL
  internal let backups: URL
  internal let logs: URL
  internal let cache: URL
  internal let config: URL
  internal let bin: URL

  internal init(fileManager: FileManager = .default) throws {
    let base = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ).appendingPathComponent(Self.bundleDirectoryName, isDirectory: true)

    self.root = base
    self.backups = base.appendingPathComponent("backups", isDirectory: true)
    self.logs = base.appendingPathComponent("logs", isDirectory: true)
    self.cache = base.appendingPathComponent("cache", isDirectory: true)
    self.config = base.appendingPathComponent("config", isDirectory: true)
    self.bin = base.appendingPathComponent("bin", isDirectory: true)

    for url in [root, backups, logs, cache, config, bin] {
      try fileManager.createDirectory(
        at: url, withIntermediateDirectories: true
      )
    }
  }

  /// For tests: build against a sandboxed base (e.g., temp dir) instead of
  /// the real Application Support.
  internal init(overrideRoot: URL, fileManager: FileManager = .default) throws {
    self.root = overrideRoot
    self.backups = overrideRoot.appendingPathComponent("backups", isDirectory: true)
    self.logs = overrideRoot.appendingPathComponent("logs", isDirectory: true)
    self.cache = overrideRoot.appendingPathComponent("cache", isDirectory: true)
    self.config = overrideRoot.appendingPathComponent("config", isDirectory: true)
    self.bin = overrideRoot.appendingPathComponent("bin", isDirectory: true)
    for url in [root, backups, logs, cache, config, bin] {
      try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
  }
}
