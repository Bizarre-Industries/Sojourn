// Sojourn — BackupsDirectory
//
// Owns the `~/Library/Application Support/Sojourn/backups/` subtree:
// creates dated snapshot dirs, enumerates existing snapshots, and GCs
// entries older than the retention window. Never `rm -rf` — always
// `NSFileManager.trashItem`. See docs/ARCHITECTURE.md §6.

import Foundation

internal actor BackupsDirectory {
  internal static let retentionDays: Int = 30

  private let paths: AppSupportPaths
  private let fileManager: FileManager

  internal init(paths: AppSupportPaths, fileManager: FileManager = .default) {
    self.paths = paths
    self.fileManager = fileManager
  }

  internal func createSnapshotDir(
    for operation: HistoryEntry.Kind,
    at date: Date = Date()
  ) throws -> URL {
    let stamp = Self.formatter.string(from: date)
      .replacingOccurrences(of: ":", with: "-")
    let dirName = "\(stamp)-\(operation.rawValue)"
    let url = paths.backups.appendingPathComponent(dirName, isDirectory: true)
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  internal func list() throws -> [URL] {
    guard fileManager.fileExists(atPath: paths.backups.path) else { return [] }
    let contents = try fileManager.contentsOfDirectory(
      at: paths.backups,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    )
    return contents.sorted { lhs, rhs in
      let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate) ?? .distantPast
      let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate) ?? .distantPast
      return lDate > rDate
    }
  }

  @discardableResult
  internal func garbageCollect(now: Date = Date()) throws -> Int {
    let cutoff = now.addingTimeInterval(-Double(Self.retentionDays) * 86400)
    var trashed = 0
    for url in try list() {
      let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate) ?? now
      if modified < cutoff {
        try fileManager.trashItem(at: url, resultingItemURL: nil)
        trashed += 1
      }
    }
    return trashed
  }

  /// Build a fresh ISO8601 formatter per call. `ISO8601DateFormatter` is not
  /// Sendable, so we avoid caching it as a static.
  internal static var formatter: ISO8601DateFormatter {
    let f = ISO8601DateFormatter()
    f.formatOptions = [
      .withYear, .withMonth, .withDay, .withTime,
      .withDashSeparatorInDate, .withColonSeparatorInTime
    ]
    return f
  }
}
