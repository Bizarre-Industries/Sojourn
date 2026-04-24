// Sojourn — GitService
//
// Subprocess wrapper over /usr/bin/git. Uses argv invocation and porcelain
// v2 -z output for stable machine parsing. Never shells out through
// /bin/sh -c. See docs/ARCHITECTURE.md §3a and CLAUDE.md ("Do not call
// /bin/bash -c ..."). No libgit2 or SwiftGit2 per docs/LICENSING.md §1.

import Foundation

internal struct GitError: Error, Sendable, Equatable, CustomStringConvertible {
  internal let code: Int32
  internal let stderr: String
  internal let command: [String]

  internal var description: String {
    "git \(command.joined(separator: " ")) exited \(code): \(stderr)"
  }
}

internal struct GitStatusEntry: Sendable, Hashable {
  internal let path: String
  internal let indexStatus: Character
  internal let worktreeStatus: Character

  internal var isClean: Bool { indexStatus == "." && worktreeStatus == "." }
}

internal struct GitAheadBehind: Sendable, Hashable {
  internal let ahead: Int
  internal let behind: Int
}

internal actor GitService {
  internal typealias Runner = @Sendable ([String], URL?) async throws -> SubprocessResult

  private let runCommand: Runner
  internal let gitURL: URL

  internal init(gitURL: URL, runCommand: @escaping Runner) {
    self.gitURL = gitURL
    self.runCommand = runCommand
  }

  internal static func live(
    runner: SubprocessRunner,
    locator: ToolLocator
  ) async -> GitService? {
    let git = await locator.locate("git")
      ?? ToolResolution(tool: "git", url: URL(fileURLWithPath: "/usr/bin/git"), source: .candidate)
    guard FileManager.default.isExecutableFile(atPath: git.url.path) else {
      return nil
    }
    return GitService(gitURL: git.url, runCommand: { args, cwd in
      try await runner.run(tool: git.url, args: args, env: Self.env, cwd: cwd, timeout: 60)
    })
  }

  internal static let env: [String: String] = [
    "PATH": "/usr/bin:/bin",
    "GIT_TERMINAL_PROMPT": "0",
    "GIT_PAGER": "cat",
    "LC_ALL": "C",
  ]

  // MARK: - Queries

  internal func revParse(_ rev: String = "HEAD", cwd: URL) async throws -> String {
    let r = try await runCommand(["rev-parse", rev], cwd)
    return r.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  internal func currentBranch(cwd: URL) async throws -> String {
    let r = try await runCommand(["rev-parse", "--abbrev-ref", "HEAD"], cwd)
    return r.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  internal func remoteURL(name: String = "origin", cwd: URL) async throws -> String? {
    do {
      let r = try await runCommand(["remote", "get-url", name], cwd)
      return r.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      return nil
    }
  }

  internal func status(cwd: URL) async throws -> [GitStatusEntry] {
    let r = try await runCommand(["status", "--porcelain=v2", "-z"], cwd)
    return Self.parseStatusPorcelain(r.stdoutString)
  }

  internal func aheadBehind(
    upstream: String = "@{upstream}",
    cwd: URL
  ) async throws -> GitAheadBehind {
    let r = try await runCommand(
      ["rev-list", "--left-right", "--count", "HEAD...\(upstream)"],
      cwd
    )
    let parts = r.stdoutString.split(separator: "\t")
      .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    if parts.count == 2 {
      return GitAheadBehind(ahead: parts[0], behind: parts[1])
    }
    return GitAheadBehind(ahead: 0, behind: 0)
  }

  // MARK: - Writes

  internal func add(paths: [String], cwd: URL) async throws {
    _ = try await runCommand(["add", "--"] + paths, cwd)
  }

  internal func commit(
    message: String,
    signoff: Bool = true,
    cwd: URL
  ) async throws -> String {
    var args = ["commit", "-m", message]
    if signoff { args.append("-s") }
    let r = try await runCommand(args, cwd)
    return r.stdoutString
  }

  internal func push(remote: String = "origin", branch: String, cwd: URL) async throws {
    _ = try await runCommand(["push", remote, branch], cwd)
  }

  internal func pull(remote: String = "origin", branch: String, cwd: URL) async throws {
    _ = try await runCommand(["pull", "--ff-only", remote, branch], cwd)
  }

  internal func clone(url: String, dest: URL, cwd: URL? = nil) async throws {
    _ = try await runCommand(["clone", url, dest.path], cwd)
  }

  internal func initRepo(at dir: URL, bare: Bool = false) async throws {
    var args = ["init"]
    if bare { args.append("--bare") }
    args.append(dir.path)
    _ = try await runCommand(args, nil)
  }

  // MARK: - Parsing

  internal static func parseStatusPorcelain(_ raw: String) -> [GitStatusEntry] {
    var out: [GitStatusEntry] = []
    for chunk in raw.split(separator: "\0", omittingEmptySubsequences: true) {
      let parts = chunk.split(separator: " ", omittingEmptySubsequences: false)
      guard parts.count >= 9, parts[0] == "1" else { continue }
      let xy = parts[1]
      guard xy.count == 2 else { continue }
      let idx = xy.first ?? "."
      let wt = xy[xy.index(after: xy.startIndex)]
      let path = parts[8...].joined(separator: " ")
      out.append(GitStatusEntry(
        path: path,
        indexStatus: idx,
        worktreeStatus: wt
      ))
    }
    return out
  }
}
