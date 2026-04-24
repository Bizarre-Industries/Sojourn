// Sojourn — MPMService
//
// Subprocess wrapper over `mpm` (meta-package-manager) 6.x. See
// docs/ARCHITECTURE.md §3b and §5.1. Key facts:
//
//   - mpm 6.x renamed --output-format to --table-format. Pin to 6.x.
//   - Default timeout is 90s per manager; `mpm` fan-outs across brew, cask,
//     mas, pip, pipx, npm, cargo, gem, composer, yarn, vscode, uvx.
//   - Never install mpm via a curl | bash script. See docs/BOOTSTRAP.md.

import Foundation

internal enum MPMError: Error, Sendable {
  case notInstalled
  case decodeFailed(String)
}

internal actor MPMService {
  internal typealias Runner = @Sendable ([String]) async throws -> SubprocessResult

  private let runCommand: Runner
  private let decoder: JSONDecoder
  internal let mpmURL: URL

  internal init(mpmURL: URL, runCommand: @escaping Runner) {
    self.mpmURL = mpmURL
    self.runCommand = runCommand
    self.decoder = JSONDecoder()
  }

  internal static func live(
    runner: SubprocessRunner,
    locator: ToolLocator
  ) async -> MPMService? {
    guard let mpm = await locator.locate("mpm") else { return nil }
    return MPMService(mpmURL: mpm.url, runCommand: { args in
      try await runner.run(tool: mpm.url, args: args, timeout: 90)
    })
  }

  /// Construct with a fixture-backed closure (tests).
  internal static func mock(
    response: @escaping @Sendable ([String]) async throws -> Data
  ) -> MPMService {
    MPMService(
      mpmURL: URL(fileURLWithPath: "/opt/homebrew/bin/mpm"),
      runCommand: { args in
        let data = try await response(args)
        return SubprocessResult(exitCode: 0, stdout: data, stderr: Data())
      }
    )
  }

  // MARK: - Public surface

  internal func version() async throws -> String {
    let r = try await runCommand(["--version"])
    return r.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  internal func installed() async throws -> [String: ManagerSnapshot] {
    let r = try await runCommand(["installed", "--table-format", "json"])
    return try decode(r.stdout)
  }

  internal func outdated() async throws -> [String: ManagerSnapshot] {
    let r = try await runCommand(["outdated", "--table-format", "json"])
    return try decode(r.stdout)
  }

  internal func backup(to path: URL) async throws {
    _ = try await runCommand(["backup", "--output", path.path])
  }

  internal func restore(from path: URL) async throws {
    _ = try await runCommand(["restore", "--input", path.path])
  }

  internal func install(manager: String, pkgs: [String]) async throws {
    _ = try await runCommand(["--manager", manager, "install"] + pkgs)
  }

  internal func remove(manager: String, pkgs: [String]) async throws {
    _ = try await runCommand(["--manager", manager, "remove"] + pkgs)
  }

  internal func upgrade(manager: String, pkgs: [String] = []) async throws {
    _ = try await runCommand(["--manager", manager, "upgrade"] + pkgs)
  }

  // MARK: - Private

  private func decode(_ data: Data) throws -> [String: ManagerSnapshot] {
    do {
      return try decoder.decode([String: ManagerSnapshot].self, from: data)
    } catch {
      let preview = String(decoding: data.prefix(200), as: UTF8.self)
      throw MPMError.decodeFailed(preview)
    }
  }
}
