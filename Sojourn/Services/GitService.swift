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
    "LC_ALL": "C"
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

  internal func stagedPaths(cwd: URL) async throws -> [String] {
    let r = try await runCommand(["diff", "--cached", "--name-only", "-z"], cwd)
    return r.stdoutString
      .split(separator: "\0", omittingEmptySubsequences: true)
      .map(String.init)
  }

  internal func aheadBehind(
    upstream: String = "@{upstream}",
    cwd: URL
  ) async throws -> GitAheadBehind {
    // Reject revspecs starting with `-` to prevent git argument confusion
    // (council 2026-05-04 stage5 security condition).
    guard !upstream.hasPrefix("-") else {
      throw GitError(code: -1, stderr: "invalid revspec: \(upstream)", command: ["rev-list"])
    }
    let r = try await runCommand(
      ["rev-list", "--left-right", "--count", "HEAD...\(upstream)", "--"],
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

  internal func unstage(paths: [String], cwd: URL) async throws {
    _ = try await runCommand(["reset", "--"] + paths, cwd)
  }

  internal func commit(
    message: String,
    signoff: Bool = true,
    paths: [String] = [],
    cwd: URL
  ) async throws -> String {
    var args = ["commit", "-m", message]
    if signoff { args.append("-s") }
    if !paths.isEmpty {
      args += ["--"] + paths
    }
    let r = try await runCommand(args, cwd)
    return r.stdoutString
  }

  internal func push(remote: String = "origin", branch: String, cwd: URL) async throws {
    _ = try await runCommand(["push", remote, branch], cwd)
  }

  internal func pull(remote: String = "origin", branch: String, cwd: URL) async throws {
    _ = try await runCommand(["pull", "--ff-only", remote, branch], cwd)
  }

  /// Pull with rebase (replays local commits on top of inbound). Used by
  /// ConflictResolver `.rebase` choice per ADR-0026.
  internal func pullRebase(remote: String = "origin", branch: String, cwd: URL) async throws {
    _ = try await runCommand(["pull", "--rebase", remote, branch], cwd)
  }

  /// Pull with merge (records merge commit). Used by ConflictResolver
  /// `.merge` choice per ADR-0026.
  internal func pullMerge(remote: String = "origin", branch: String, cwd: URL) async throws {
    _ = try await runCommand(["pull", "--no-rebase", remote, branch], cwd)
  }

  /// Fetch remote refs without merging. Cheap precursor to divergence
  /// detection. ADR-0026 amendment: fires on user gesture or
  /// cooldown-elapsed background sync only — NOT on every SyncPane
  /// appearance.
  internal func fetch(remote: String = "origin", cwd: URL) async throws {
    _ = try await runCommand(["fetch", "--quiet", remote], cwd)
  }

  /// Abort an in-progress rebase, restoring HEAD to the pre-rebase
  /// commit. Best-effort cleanup invoked by ConflictResolver after a
  /// failed `pullRebase`.
  internal func rebaseAbort(cwd: URL) async throws {
    _ = try await runCommand(["rebase", "--abort"], cwd)
  }

  /// Abort an in-progress merge, restoring index + working tree.
  /// Best-effort cleanup invoked by ConflictResolver after a failed
  /// `pullMerge`.
  internal func mergeAbort(cwd: URL) async throws {
    _ = try await runCommand(["merge", "--abort"], cwd)
  }

  /// Structured list of commits present on `upstream` but not on `since`.
  /// Hard-capped at `limit` (200 by default per ADR-0026 amendment) to
  /// bound parse cost on long-asleep machines.
  internal func inboundCommits(
    since: String = "HEAD",
    upstream: String = "@{upstream}",
    cwd: URL,
    limit: Int = 200
  ) async throws -> [InboundCommit] {
    // Reject revspecs starting with `-` to prevent git argument confusion
    // (council 2026-05-04 stage5 security condition).
    guard !since.hasPrefix("-"), !upstream.hasPrefix("-") else {
      throw GitError(
        code: -1,
        stderr: "invalid revspec: \(since)..\(upstream)",
        command: ["log"]
      )
    }
    let r = try await runCommand(
      [
        "log",
        "--max-count=\(limit)",
        "--pretty=format:%H%x09%an%x09%aI%x09%s",
        "--shortstat",
        "\(since)..\(upstream)",
        "--"
      ],
      cwd
    )
    return Self.parseInboundCommits(r.stdoutString)
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

  /// Parse `git log --pretty=format:%H%x09%an%x09%aI%x09%s --shortstat`
  /// into a list of `InboundCommit`s. Each commit is a header line
  /// (sha\tauthor\tISO8601\tsubject) optionally followed by a shortstat
  /// line ("N files changed, M insertions(+), K deletions(-)").
  /// Tolerates missing shortstats (commits with no file changes).
  internal static func parseInboundCommits(_ raw: String) -> [InboundCommit] {
    var out: [InboundCommit] = []
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]

    var lines = raw.split(separator: "\n", omittingEmptySubsequences: true)
      .map { String($0) }
    while !lines.isEmpty {
      let header = lines.removeFirst()
      let parts = header.split(separator: "\t", omittingEmptySubsequences: false)
      guard parts.count >= 4 else { continue }
      let sha = String(parts[0])
      let author = String(parts[1])
      guard let date = formatter.date(from: String(parts[2])) else { continue }
      let subject = parts[3...].joined(separator: "\t")

      var filesChanged = 0
      var insertions = 0
      var deletions = 0
      if let next = lines.first, next.contains("changed,") || next.contains("change,") {
        lines.removeFirst()
        for chunk in next.split(separator: ",") {
          let trimmed = chunk.trimmingCharacters(in: .whitespaces)
          let scanner = Scanner(string: trimmed)
          guard let n = scanner.scanInt() else { continue }
          if trimmed.contains("file") { filesChanged = n }
          else if trimmed.contains("insertion") { insertions = n }
          else if trimmed.contains("deletion") { deletions = n }
        }
      }

      out.append(InboundCommit(
        sha: sha,
        author: author,
        date: date,
        subject: subject,
        filesChanged: filesChanged,
        insertions: insertions,
        deletions: deletions
      ))
    }
    return out
  }
}
