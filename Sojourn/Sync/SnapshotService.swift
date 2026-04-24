// Sojourn — SnapshotService
//
// Takes a pre-operation snapshot before any destructive sync or apply.
// See docs/ARCHITECTURE.md §6. Uses /usr/bin/tar for archive creation so
// we stay aligned with CLAUDE.md "prefer boring, documented Apple APIs".

import Foundation

internal enum SnapshotError: Error, Sendable {
  case missingSource(URL)
  case tarFailed(String)
}

internal actor SnapshotService {
  internal typealias Runner = @Sendable (URL, [String], URL?) async throws -> SubprocessResult

  private let backups: BackupsDirectory
  private let runCommand: Runner
  internal let tarURL: URL

  internal init(
    backups: BackupsDirectory,
    tarURL: URL = URL(fileURLWithPath: "/usr/bin/tar"),
    runCommand: @escaping Runner
  ) {
    self.backups = backups
    self.tarURL = tarURL
    self.runCommand = runCommand
  }

  internal static func live(backups: BackupsDirectory, runner: SubprocessRunner) -> SnapshotService {
    SnapshotService(backups: backups, runCommand: { tool, args, cwd in
      try await runner.run(tool: tool, args: args, cwd: cwd, timeout: 300)
    })
  }

  @discardableResult
  internal func capture(operation: HistoryEntry.Kind, sources: [URL]) async throws -> Snapshot {
    let dir = try await backups.createSnapshotDir(for: operation)
    var size: Int64 = 0

    for source in sources {
      guard FileManager.default.fileExists(atPath: source.path) else { continue }
      let dest = dir.appendingPathComponent(
        source.lastPathComponent + ".tar", isDirectory: false
      )
      let parent = source.deletingLastPathComponent()
      let args = ["-cf", dest.path, "-C", parent.path, source.lastPathComponent]
      do {
        _ = try await runCommand(tarURL, args, nil)
      } catch {
        throw SnapshotError.tarFailed("\(source.path): \(error)")
      }
      if let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path),
         let s = attrs[.size] as? Int64 {
        size += s
      }
    }

    return Snapshot(
      operation: operation,
      path: dir,
      createdAt: Date(),
      sizeBytes: size,
      rollbackHint: "Restore by `tar -xf` each archive in the snapshot dir to its original parent."
    )
  }
}
