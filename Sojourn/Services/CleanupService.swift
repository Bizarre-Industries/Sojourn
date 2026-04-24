// Sojourn — CleanupService
//
// Scans ~/.* (dotfiles) and ~/Library/** (Application Support, Caches,
// Preferences, Saved Application State, HTTPStorages) to find orphan
// candidates — files owned by apps no longer installed. See
// docs/ARCHITECTURE.md §10. Never `rm`; uses NSFileManager.trashItem with
// a DeletionsDB audit trail.

import Foundation
#if canImport(AppKit)
import AppKit
#endif

internal actor CleanupService {
  private let fileManager: FileManager
  private let deletionsDB: DeletionsDB
  private var dotfileOwners: [String: DotfileOwner] = [:]

  internal init(fileManager: FileManager = .default, deletionsDB: DeletionsDB) {
    self.fileManager = fileManager
    self.deletionsDB = deletionsDB
  }

  internal func loadBundledRegistry() {
    // Resource lookup differs between SPM (Bundle.module flattened by
    // .process) and Xcode app bundles (Contents/Resources). Both are
    // probed below.
    let url: URL? = {
      #if SWIFT_PACKAGE
      return Bundle.module.url(forResource: "dotfile_owners", withExtension: "toml")
      #else
      return Bundle.main.url(
        forResource: "dotfile_owners", withExtension: "toml", subdirectory: "data"
      ) ?? Bundle.main.url(forResource: "dotfile_owners", withExtension: "toml")
      #endif
    }()
    guard let url, let text = try? String(contentsOf: url) else {
      return
    }
    if let table = try? SojournFileCodec().decode(text),
       case .array(let owners)? = table["owner"] {
      for item in owners {
        guard case .table(let t) = item,
              let path = t["path"]?.stringValue,
              let ownerRaw = t["owner"]?.stringValue,
              let owner = DotfileOwner.Owner(rawValue: ownerRaw)
        else { continue }
        dotfileOwners[path] = DotfileOwner(
          path: path,
          owner: owner,
          manager: t["manager"]?.stringValue,
          notes: t["notes"]?.stringValue
        )
      }
    }
  }

  internal func owners() -> [DotfileOwner] {
    Array(dotfileOwners.values).sorted { $0.path < $1.path }
  }

  internal func scan(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> [OrphanCandidate] {
    var out: [OrphanCandidate] = []

    let library = homeURL.appendingPathComponent("Library", isDirectory: true)
    out.append(contentsOf: scan(subtree: library.appendingPathComponent("Caches"),
                                category: .safe, reason: "cache directory"))
    out.append(contentsOf: scan(subtree: library.appendingPathComponent("Application Support"),
                                category: .review, reason: "application support"))
    out.append(contentsOf: scan(subtree: library.appendingPathComponent("HTTPStorages"),
                                category: .review, reason: "HTTP storage"))
    out.append(contentsOf: scan(subtree: library.appendingPathComponent("Preferences"),
                                category: .risky, reason: "preferences plist"))
    out.append(contentsOf: scan(subtree: library.appendingPathComponent("Saved Application State"),
                                category: .risky, reason: "saved app state"))

    if let entries = try? fileManager.contentsOfDirectory(
      at: homeURL,
      includingPropertiesForKeys: [
        .isDirectoryKey, .contentModificationDateKey, .totalFileAllocatedSizeKey
      ]
    ) {
      for url in entries {
        let name = url.lastPathComponent
        guard name.hasPrefix(".") else { continue }
        let owner = dotfileOwners[name]
        if owner == nil || owner?.owner == .unknown {
          out.append(OrphanCandidate(
            path: url,
            bundleID: nil,
            category: .review,
            sizeBytes: Self.size(of: url),
            lastModifiedAt: Self.mtime(of: url),
            reason: "unmanaged dotfile (no registry entry)"
          ))
        }
      }
    }
    return out
  }

  @discardableResult
  internal func trash(_ candidate: OrphanCandidate) async throws -> Int64 {
    try fileManager.trashItem(at: candidate.path, resultingItemURL: nil)
    return try await deletionsDB.record(
      path: candidate.path.path,
      reason: candidate.reason,
      rollbackPossible: true
    )
  }

  // MARK: - Private

  private func scan(
    subtree: URL,
    category: OrphanCandidate.Category,
    reason: String
  ) -> [OrphanCandidate] {
    guard fileManager.fileExists(atPath: subtree.path) else { return [] }
    guard let entries = try? fileManager.contentsOfDirectory(
      at: subtree,
      includingPropertiesForKeys: [
        .isDirectoryKey, .contentModificationDateKey, .totalFileAllocatedSizeKey
      ],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    var out: [OrphanCandidate] = []
    for url in entries {
      let bundleID = Self.extractBundleID(from: url)
      if let bundleID, Self.isInstalled(bundleID: bundleID) { continue }
      out.append(OrphanCandidate(
        path: url,
        bundleID: bundleID,
        category: category,
        sizeBytes: Self.size(of: url),
        lastModifiedAt: Self.mtime(of: url),
        reason: "\(reason) for \(bundleID ?? url.lastPathComponent)"
      ))
    }
    return out
  }

  private static func size(of url: URL) -> Int64 {
    guard let v = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize else {
      return 0
    }
    return Int64(v)
  }

  private static func mtime(of url: URL) -> Date? {
    try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
  }

  private static func extractBundleID(from url: URL) -> String? {
    let name = url.lastPathComponent
    let stripped = name.hasSuffix(".plist") ? String(name.dropLast(6)) : name
    if stripped.split(separator: ".").count >= 3 {
      return stripped
    }
    return nil
  }

  private static func isInstalled(bundleID: String) -> Bool {
    #if canImport(AppKit)
    return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    #else
    return false
    #endif
  }
}
