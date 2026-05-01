// Sojourn — BrewBundleService
//
// Single backend per ADR-0018. Wraps `brew bundle {dump,install,check,
// cleanup}` via the shared `SubprocessRunner`. Brewfile path is always
// validated through `realpath` against the chezmoi source root before
// invocation (security-council condition on ADR-0021 generalised to all
// user-supplied paths). All `brew` invocations use **argv array form**
// — never a shell-interpreted string.
//
// Refs: ADR-0018; docs/process/plans/v0.2-plan.md step 5;
// .claude/council-logs/2026-05-01-v0.2-adr-batch.md.

import Foundation

/// Errors the BrewBundleService can surface to JobRunner.
internal enum BrewBundleError: Error, Sendable, CustomStringConvertible {
  case brewNotFound
  case brewfileNotFound(URL)
  case brewfilePathRejected(String, reason: String)
  case nonZeroExit(code: Int32, stderr: String)
  case unparseableOutput(String)

  internal var description: String {
    switch self {
    case .brewNotFound:
      return "brew CLI not found in PATH"
    case .brewfileNotFound(let url):
      return "Brewfile not found at \(url.path)"
    case .brewfilePathRejected(let path, let reason):
      return "Brewfile path rejected: \(path) (\(reason))"
    case .nonZeroExit(let code, let stderr):
      let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
      return "brew bundle exited \(code): \(trimmed)"
    case .unparseableOutput(let preview):
      return "brew bundle produced output we could not parse: \(preview)"
    }
  }
}

/// Result of a `brew bundle install/upgrade/check/cleanup` run.
internal struct BrewBundleRunSummary: Sendable, Equatable {
  internal let exitCode: Int32
  internal let stdoutLineCount: Int
  internal let durationSeconds: Double
  internal let upgrade: Bool
  internal let cleanup: Bool

  internal var didSucceed: Bool { exitCode == 0 }
}

/// Top-level actor over `brew bundle`. One instance per app — held by
/// `AppStore.live()`.
internal actor BrewBundleService {
  private let runner: SubprocessRunner
  private let brewURL: URL
  private let chezmoiSourceRoot: URL?

  internal init(
    runner: SubprocessRunner,
    brewURL: URL,
    chezmoiSourceRoot: URL? = nil
  ) {
    self.runner = runner
    self.brewURL = brewURL
    self.chezmoiSourceRoot = chezmoiSourceRoot
  }

  // MARK: - Path validation

  /// Resolve and validate a user-supplied Brewfile path. Returns the
  /// canonical absolute URL. Throws `.brewfilePathRejected` when the
  /// path resolves outside the chezmoi source root or
  /// `~/.config/sojourn/`.
  internal func validateBrewfile(_ path: URL) throws -> URL {
    let resolved = path.resolvingSymlinksInPath().standardizedFileURL
    if !FileManager.default.fileExists(atPath: resolved.path) {
      throw BrewBundleError.brewfileNotFound(resolved)
    }
    let allowed = allowedRoots()
    let resolvedPath = resolved.path
    let isUnder = allowed.contains { root in
      resolvedPath == root.path || resolvedPath.hasPrefix(root.path + "/")
    }
    if !isUnder {
      throw BrewBundleError.brewfilePathRejected(
        resolvedPath,
        reason: "outside allowed roots (\(allowed.map(\.path).joined(separator: ", ")))"
      )
    }
    return resolved
  }

  private func allowedRoots() -> [URL] {
    var roots: [URL] = []
    if let cz = chezmoiSourceRoot {
      roots.append(cz.standardizedFileURL)
    }
    let home = FileManager.default.homeDirectoryForCurrentUser
    roots.append(home.appendingPathComponent(".config/sojourn", isDirectory: true)
      .standardizedFileURL)
    return roots
  }

  // MARK: - Dump

  /// `brew bundle dump --file=- --all`. Returns the parsed AST.
  internal func dump(allEcosystems: Bool = true) async throws -> BrewfileAST {
    var args = ["bundle", "dump", "--file=-"]
    if allEcosystems { args.append("--all") }
    let result = try await runner.run(
      tool: brewURL,
      args: args,
      timeout: 120
    )
    guard result.exitCode == 0 else {
      throw BrewBundleError.nonZeroExit(code: result.exitCode, stderr: result.stderrString)
    }
    return BrewfileParser.parse(result.stdoutString)
  }

  /// `brew bundle dump --file=<path> --force`. Writes the Brewfile to
  /// disk (replaces if present).
  internal func dump(to path: URL, allEcosystems: Bool = true) async throws {
    var args = ["bundle", "dump", "--file=\(path.path)", "--force"]
    if allEcosystems { args.append("--all") }
    let result = try await runner.run(
      tool: brewURL,
      args: args,
      timeout: 120
    )
    guard result.exitCode == 0 else {
      throw BrewBundleError.nonZeroExit(code: result.exitCode, stderr: result.stderrString)
    }
  }

  // MARK: - Install

  /// `brew bundle install --file=<path> [--upgrade] [--cleanup]`.
  /// `path` is validated before invocation.
  ///
  /// Per perf-council condition: install/upgrade jobs are timeout-exempt
  /// but cancellable via `Task.cancel()`. Caller is JobRunner; its
  /// cooperative cancellation forwards to `SubprocessRunner` which sends
  /// SIGTERM then SIGKILL after a grace period.
  internal func install(
    file path: URL,
    upgrade: Bool = false,
    cleanup: Bool = false
  ) async throws -> BrewBundleRunSummary {
    let validated = try validateBrewfile(path)
    var args = ["bundle", "install", "--file=\(validated.path)"]
    if upgrade { args.append("--upgrade") }
    if cleanup { args.append("--cleanup") }

    let started = Date()
    let result = try await runner.run(
      tool: brewURL,
      args: args,
      timeout: nil   // no timeout for install — jobs are long-running
    )
    let duration = Date().timeIntervalSince(started)
    if result.exitCode != 0 {
      throw BrewBundleError.nonZeroExit(code: result.exitCode, stderr: result.stderrString)
    }
    return BrewBundleRunSummary(
      exitCode: result.exitCode,
      stdoutLineCount: result.stdoutString.split(separator: "\n").count,
      durationSeconds: duration,
      upgrade: upgrade,
      cleanup: cleanup
    )
  }

  // MARK: - Check

  /// `brew bundle check --file=<path>`. Returns `true` if everything is
  /// installed (exit 0); `false` if the Brewfile lists missing entries
  /// (exit 1). Other exit codes throw.
  internal func check(file path: URL) async throws -> Bool {
    let validated = try validateBrewfile(path)
    let result = try await runner.run(
      tool: brewURL,
      args: ["bundle", "check", "--file=\(validated.path)"],
      timeout: 60
    )
    switch result.exitCode {
    case 0:  return true
    case 1:  return false
    default:
      throw BrewBundleError.nonZeroExit(code: result.exitCode, stderr: result.stderrString)
    }
  }

  // MARK: - Read

  /// Read + parse a Brewfile from disk. Used to populate AppStore
  /// snapshots without invoking brew at all.
  internal func parse(file path: URL) async throws -> BrewfileAST {
    let validated = try validateBrewfile(path)
    let text = try String(contentsOf: validated, encoding: .utf8)
    return BrewfileParser.parse(text)
  }
}
