// Sojourn — ConflictResolverTests
//
// End-to-end exercise of the refuse-and-show-diff state machine against
// a real local bare git repo as the "remote" per CLAUDE.md test rule
// "SyncCoordinator push/pull flows: end-to-end tests using a local bare
// git repo as the 'remote.'" Same pattern as SyncTests.swift.
//
// Cases:
//   - clean: remote and local at same SHA → .clean after detect
//   - behind-only: remote has commits → .conflictPending after detect
//   - rebase-success: rebase choice resolves to .resolved
//   - merge-success: merge choice resolves to .resolved
//   - abort: abort choice → .blockedFromPush, canPush == false
//   - reset: returns to .clean
//
// Refs: ADR-0026 multi-machine conflict UX.

import Testing
import Foundation
@testable import Sojourn

@MainActor
struct ConflictResolverTests {
  // MARK: - Fixture helpers

  private func makeBareRemote() async throws -> (
    remote: URL,
    workA: URL,
    git: GitService,
    cleanup: @Sendable () -> Void
  ) {
    let runner = SubprocessRunner()
    let locator = ToolLocator()
    guard let git = await GitService.live(runner: runner, locator: locator) else {
      throw GitError(code: -1, stderr: "git not available", command: ["live"])
    }

    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-resolver-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    let remote = workroot.appendingPathComponent("origin.git")
    let workA = workroot.appendingPathComponent("workA")

    try await git.initRepo(at: remote, bare: true)
    try await git.clone(url: remote.path, dest: workA)

    // CI-safe git identity + force main branch (matches SyncTests).
    for args in [
      ["-C", workA.path, "config", "user.email", "test@example.invalid"],
      ["-C", workA.path, "config", "user.name", "Test User"],
      ["-C", workA.path, "config", "commit.gpgsign", "false"],
      ["-C", workA.path, "config", "init.defaultBranch", "main"],
      ["-C", workA.path, "checkout", "-b", "main"]
    ] {
      _ = try? await runner.run(
        tool: URL(fileURLWithPath: "/usr/bin/git"),
        args: args
      )
    }

    // Seed an initial commit so origin/main exists.
    try Data("# seed\n".utf8).write(to: workA.appendingPathComponent("README.md"))
    try await git.add(paths: ["README.md"], cwd: workA)
    _ = try await git.commit(message: "seed", signoff: false, cwd: workA)
    try await git.push(remote: "origin", branch: "main", cwd: workA)
    // After push, set upstream so aheadBehind('@{upstream}') resolves.
    _ = try? await runner.run(
      tool: URL(fileURLWithPath: "/usr/bin/git"),
      args: ["-C", workA.path, "branch", "--set-upstream-to=origin/main", "main"]
    )

    let cleanup: @Sendable () -> Void = {
      try? FileManager.default.removeItem(at: workroot)
    }
    return (remote, workA, git, cleanup)
  }

  private func sideloadCommit(
    via git: GitService,
    remote: URL,
    workroot: URL,
    fileName: String,
    body: String,
    message: String
  ) async throws {
    let runner = SubprocessRunner()
    let workB = workroot.appendingPathComponent("workB-\(UUID().uuidString)")
    try await git.clone(url: remote.path, dest: workB)
    for args in [
      ["-C", workB.path, "config", "user.email", "test@example.invalid"],
      ["-C", workB.path, "config", "user.name", "Test User"],
      ["-C", workB.path, "config", "commit.gpgsign", "false"],
      ["-C", workB.path, "checkout", "main"]
    ] {
      _ = try? await runner.run(
        tool: URL(fileURLWithPath: "/usr/bin/git"),
        args: args
      )
    }
    try Data(body.utf8).write(to: workB.appendingPathComponent(fileName))
    try await git.add(paths: [fileName], cwd: workB)
    _ = try await git.commit(message: message, signoff: false, cwd: workB)
    try await git.push(remote: "origin", branch: "main", cwd: workB)
  }

  // MARK: - Tests

  @Test
  func cleanState_whenNoInboundCommits() async throws {
    let (_, workA, git, cleanup) = try await makeBareRemote()
    defer { cleanup() }

    let resolver = ConflictResolver(git: git, repoURL: workA)
    await resolver.detect()
    #expect(resolver.state == .clean)
    #expect(resolver.canPush)
  }

  @Test
  func conflictPending_whenRemoteAhead() async throws {
    let (remote, workA, git, cleanup) = try await makeBareRemote()
    defer { cleanup() }
    let workroot = workA.deletingLastPathComponent()

    try await sideloadCommit(
      via: git, remote: remote, workroot: workroot,
      fileName: "from-other-machine.txt",
      body: "alpha\n",
      message: "feat: add alpha"
    )

    let resolver = ConflictResolver(git: git, repoURL: workA)
    await resolver.detect()

    if case .conflictPending(let commits) = resolver.state {
      #expect(commits.count == 1)
      #expect(commits.first?.subject == "feat: add alpha")
    } else {
      Issue.record("expected .conflictPending, got \(resolver.state)")
    }
    #expect(!resolver.canPush)
  }

  @Test
  func rebaseChoice_resolvesToClean() async throws {
    let (remote, workA, git, cleanup) = try await makeBareRemote()
    defer { cleanup() }
    let workroot = workA.deletingLastPathComponent()

    try await sideloadCommit(
      via: git, remote: remote, workroot: workroot,
      fileName: "rebase-target.txt",
      body: "remote\n",
      message: "feat: rebase target"
    )

    let resolver = ConflictResolver(git: git, repoURL: workA)
    await resolver.detect()
    await resolver.apply(.rebase)

    #expect(resolver.state == .resolved)
    #expect(resolver.canPush)
  }

  @Test
  func mergeChoice_resolvesToClean() async throws {
    let (remote, workA, git, cleanup) = try await makeBareRemote()
    defer { cleanup() }
    let workroot = workA.deletingLastPathComponent()

    try await sideloadCommit(
      via: git, remote: remote, workroot: workroot,
      fileName: "merge-target.txt",
      body: "remote\n",
      message: "feat: merge target"
    )

    let resolver = ConflictResolver(git: git, repoURL: workA)
    await resolver.detect()
    await resolver.apply(.merge)

    #expect(resolver.state == .resolved)
    #expect(resolver.canPush)
  }

  @Test
  func abortChoice_blocksPush() async throws {
    let (remote, workA, git, cleanup) = try await makeBareRemote()
    defer { cleanup() }
    let workroot = workA.deletingLastPathComponent()

    try await sideloadCommit(
      via: git, remote: remote, workroot: workroot,
      fileName: "aborted.txt",
      body: "remote\n",
      message: "feat: aborted target"
    )

    let resolver = ConflictResolver(git: git, repoURL: workA)
    await resolver.detect()
    await resolver.apply(.abort)

    if case .blockedFromPush = resolver.state {
      // ok
    } else {
      Issue.record("expected .blockedFromPush, got \(resolver.state)")
    }
    #expect(!resolver.canPush)
    #expect(!resolver.pushBlockedReason.isEmpty)
  }

  @Test
  func reset_returnsToClean() async throws {
    let (_, workA, git, cleanup) = try await makeBareRemote()
    defer { cleanup() }

    let resolver = ConflictResolver(git: git, repoURL: workA)
    await resolver.detect()
    resolver.reset()
    #expect(resolver.state == .clean)
  }
}
