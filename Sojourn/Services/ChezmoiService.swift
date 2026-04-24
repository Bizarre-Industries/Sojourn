// Sojourn — ChezmoiService
//
// Subprocess wrapper over `chezmoi`. See docs/ARCHITECTURE.md §3c. Uses
// `--no-pager --color=false` on every invocation for stable machine
// parsing. No libgit2, no in-process chezmoi — arm's-length subprocess
// per docs/LICENSING.md §1.

import Foundation

internal struct ChezmoiManagedEntry: Sendable, Hashable, Codable, Identifiable {
  internal var id: String { absPath }
  internal let name: String
  internal let type: String
  internal let absPath: String
  internal let sourceAbsPath: String
}

internal enum ChezmoiError: Error, Sendable {
  case notInstalled
  case decodeFailed(String)
}

internal actor ChezmoiService {
  internal typealias Runner = @Sendable ([String], URL?) async throws -> SubprocessResult

  private let runCommand: Runner
  private let decoder: JSONDecoder
  internal let chezmoiURL: URL

  internal init(chezmoiURL: URL, runCommand: @escaping Runner) {
    self.chezmoiURL = chezmoiURL
    self.runCommand = runCommand
    self.decoder = JSONDecoder()
  }

  internal static func live(
    runner: SubprocessRunner,
    locator: ToolLocator
  ) async -> ChezmoiService? {
    guard let chezmoi = await locator.locate("chezmoi") else { return nil }
    return ChezmoiService(chezmoiURL: chezmoi.url, runCommand: { args, cwd in
      try await runner.run(
        tool: chezmoi.url,
        args: ["--no-pager", "--color=false"] + args,
        cwd: cwd,
        timeout: 120
      )
    })
  }

  internal static func mock(
    response: @escaping @Sendable ([String]) async throws -> Data
  ) -> ChezmoiService {
    ChezmoiService(
      chezmoiURL: URL(fileURLWithPath: "/opt/homebrew/bin/chezmoi"),
      runCommand: { args, _ in
        let data = try await response(args)
        return SubprocessResult(exitCode: 0, stdout: data, stderr: Data())
      }
    )
  }

  // MARK: - Queries

  internal func version() async throws -> String {
    let r = try await runCommand(["--version"], nil)
    return r.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  internal func managed(cwd: URL? = nil) async throws -> [ChezmoiManagedEntry] {
    let r = try await runCommand(["managed", "--format", "json"], cwd)
    do {
      return try decoder.decode([ChezmoiManagedEntry].self, from: r.stdout)
    } catch {
      let preview = String(decoding: r.stdout.prefix(200), as: UTF8.self)
      throw ChezmoiError.decodeFailed(preview)
    }
  }

  internal func status(cwd: URL? = nil) async throws -> String {
    let r = try await runCommand(["status"], cwd)
    return r.stdoutString
  }

  internal func diff(cwd: URL? = nil) async throws -> String {
    let r = try await runCommand(["diff"], cwd)
    return r.stdoutString
  }

  internal func sourcePath(cwd: URL? = nil) async throws -> URL {
    let r = try await runCommand(["source-path"], cwd)
    let trimmed = r.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
    return URL(fileURLWithPath: trimmed)
  }

  // MARK: - Writes

  internal func apply(dryRun: Bool = false, cwd: URL? = nil) async throws {
    var args = ["apply"]
    if dryRun { args.append("--dry-run") }
    _ = try await runCommand(args, cwd)
  }

  internal func add(path: String, cwd: URL? = nil) async throws {
    _ = try await runCommand(["add", path], cwd)
  }

  internal func reAdd(cwd: URL? = nil) async throws {
    _ = try await runCommand(["re-add"], cwd)
  }

  internal func forget(path: String, cwd: URL? = nil) async throws {
    _ = try await runCommand(["forget", path], cwd)
  }
}
