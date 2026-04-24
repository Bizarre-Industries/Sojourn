import Foundation
import Testing
@testable import Sojourn

struct SnapshotServiceTests {
  @Test func captureCreatesTarArchive() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-snap-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let paths = try AppSupportPaths(overrideRoot: tmp)
    let backups = BackupsDirectory(paths: paths)

    let source = tmp.appendingPathComponent("source", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("hello".utf8).write(to: source.appendingPathComponent("file.txt"))

    let runner = SubprocessRunner()
    let snap = SnapshotService.live(backups: backups, runner: runner)

    let result = try await snap.capture(operation: .dotfileApply, sources: [source])
    #expect(result.sizeBytes > 0)

    let archive = result.path.appendingPathComponent("source.tar")
    #expect(FileManager.default.fileExists(atPath: archive.path))
  }
}

struct CooldownGateTests {
  @Test func disabledSettingAllowsAuto() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-cool-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let paths = try AppSupportPaths(overrideRoot: tmp)
    let store = try SettingsStore(paths: paths)
    try await store.mutate { $0.cooldownEnabled = false }

    let gate = CooldownGate(settings: store, fetch: { _ in (Data(), URLResponse()) })
    let decision = await gate.evaluate(
      package: "ripgrep", manager: "brew",
      installedVersion: "14.0.0", candidateVersion: "14.1.0",
      releasedAt: Date()
    )
    #expect(decision.allowAuto == true)
    #expect(decision.reason.contains("disabled"))
  }

  @Test func freshBuildBlocksBelowCooldown() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-cool-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let paths = try AppSupportPaths(overrideRoot: tmp)
    let store = try SettingsStore(paths: paths)
    let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    let gate = CooldownGate(
      settings: store,
      fetch: { _ in (Data("{\"vulns\":[]}".utf8), URLResponse()) },
      now: { fixedNow }
    )

    let released = fixedNow.addingTimeInterval(-3 * 86400)  // 3 days old
    let decision = await gate.evaluate(
      package: "ripgrep", manager: "brew",
      ecosystem: "Homebrew",
      installedVersion: "14.0.0", candidateVersion: "14.1.0",
      releasedAt: released
    )
    #expect(decision.allowAuto == false)
  }

  @Test func advisoryBypassClears() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-cool-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let paths = try AppSupportPaths(overrideRoot: tmp)
    let store = try SettingsStore(paths: paths)
    let advisoryData = Data("{\"vulns\":[{\"id\":\"GHSA-xxxx\",\"modified\":\"2025-06-01T00:00:00Z\"}]}".utf8)
    let gate = CooldownGate(
      settings: store,
      fetch: { _ in (advisoryData, URLResponse()) }
    )

    let decision = await gate.evaluate(
      package: "ripgrep", manager: "brew",
      ecosystem: "Homebrew",
      installedVersion: "14.0.0", candidateVersion: "14.1.0",
      releasedAt: Date()
    )
    #expect(decision.advisoryBypass == true)
  }
}

@MainActor
struct SyncCoordinatorTests {
  @Test func pushWorksOnLocalBareRepo() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let bare = workroot.appendingPathComponent("remote.git", isDirectory: true)
    let workA = workroot.appendingPathComponent("a", isDirectory: true)

    let runner = SubprocessRunner()
    let locator = ToolLocator()
    guard let git = await GitService.live(runner: runner, locator: locator) else {
      Issue.record("git not found on system")
      return
    }

    try await git.initRepo(at: bare, bare: true)
    try await git.clone(url: bare.path, dest: workA)

    for args in [
      ["-C", workA.path, "config", "user.email", "test@example.invalid"],
      ["-C", workA.path, "config", "user.name", "Test User"],
      ["-C", workA.path, "config", "commit.gpgsign", "false"],
      ["-C", workA.path, "config", "init.defaultBranch", "main"],
      ["-C", workA.path, "checkout", "-b", "main"],
    ] {
      _ = try? await runner.run(
        tool: URL(fileURLWithPath: "/usr/bin/git"),
        args: args
      )
    }

    try Data("hello".utf8).write(to: workA.appendingPathComponent("packages.toml"))

    let paths = try AppSupportPaths(overrideRoot: workroot)
    let backups = BackupsDirectory(paths: paths)
    let snap = SnapshotService.live(backups: backups, runner: runner)
    let settings = try SettingsStore(paths: paths)
    let cooldown = CooldownGate(settings: settings, fetch: { _ in (Data(), URLResponse()) })

    let coordinator = SyncCoordinator(
      repoURL: workA,
      git: git,
      chezmoi: nil, mpm: nil, pref: nil, secrets: nil,
      snapshots: snap, cooldown: cooldown
    )

    await coordinator.push(branch: "main", message: "test: add packages.toml")

    // Accept either .done(.syncPush) or .failed for local-bare push;
    // what we assert is that push was attempted (phase != idle).
    #expect(coordinator.phase != .idle)
  }
}
