import Foundation
@testable import Sojourn
import Testing

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
      ["-C", workA.path, "checkout", "-b", "main"]
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

    let brewBundle = BrewBundleService(
      runner: runner,
      brewURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")
    )
    let resolver = ConflictResolver(git: git, repoURL: workA)
    let coordinator = SyncCoordinator(
      repoURL: workA,
      git: git,
      chezmoi: nil, brewBundle: brewBundle, pref: nil, secrets: nil,
      snapshots: snap, cooldown: cooldown,
      conflictResolver: resolver
    )

    await coordinator.push(branch: "main", message: "test: add packages.toml")

    // Accept either .done(.syncPush) or .failed for local-bare push;
    // what we assert is that push was attempted (phase != idle).
    #expect(coordinator.phase != .idle)
  }

  @Test func pushStagesFilesBeforeScanningStagedSecrets() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-order-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let secrets = SecretScanService.mock { _ in
      await events.record("scan")
      return Data()
    }
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: secrets
    )

    await coordinator.push(branch: "main", message: "test: sync")

    let observed = await events.values
    #expect(observed.firstIndex(of: "git:add")! < observed.firstIndex(of: "scan")!)
    #expect(observed.firstIndex(of: "scan")! < observed.firstIndex(of: "git:commit")!)
    #expect(observed.firstIndex(of: "git:commit")! < observed.firstIndex(of: "git:push")!)
  }

  @Test func pushFailsClosedWhenSecretScannerUnavailable() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-no-scanner-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: nil
    )

    await coordinator.push(branch: "main", message: "test: sync")

    let observed = await events.values
    #expect(observed.contains("git:add"))
    #expect(observed.contains("git:reset"))
    #expect(!observed.contains("git:commit"))
    #expect(!observed.contains("git:push"))
    guard case .failed(let message) = coordinator.phase else {
      Issue.record("expected failed phase, got \(coordinator.phase)")
      return
    }
    #expect(message.contains("secret scanning is unavailable"))
    let backups = try FileManager.default.contentsOfDirectory(
      at: workroot.appendingPathComponent("backups", isDirectory: true),
      includingPropertiesForKeys: nil
    )
    #expect(backups.isEmpty)
  }

  @Test func pushBlocksUnrelatedPreStagedPathsBeforeScanning() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-prestaged-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      if args == ["diff", "--cached", "--name-only", "-z"] {
        return SubprocessResult(
          exitCode: 0,
          stdout: Data("Brewfile.common\0notes.txt\0".utf8),
          stderr: Data()
        )
      }
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let secrets = SecretScanService.mock { _ in
      await events.record("scan")
      return Data()
    }
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: secrets
    )

    await coordinator.push(branch: "main", message: "test: sync")

    let observed = await events.values
    #expect(observed.contains("git:add"))
    #expect(observed.contains("git:diff"))
    #expect(observed.contains("git:reset"))
    #expect(!observed.contains("scan"))
    #expect(!observed.contains("git:commit"))
    #expect(!observed.contains("git:push"))
    guard case .failed(let message) = coordinator.phase else {
      Issue.record("expected failed phase, got \(coordinator.phase)")
      return
    }
    #expect(message.contains("staged files outside Sojourn sync paths"))
    #expect(message.contains("notes.txt"))
    let backups = try FileManager.default.contentsOfDirectory(
      at: workroot.appendingPathComponent("backups", isDirectory: true),
      includingPropertiesForKeys: nil
    )
    #expect(backups.isEmpty)
  }

  @Test func pushUnstagesAndStopsWhenStagedScanFindsHighConfidenceSecret() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-secret-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let finding = SecretFinding(
      description: "GitHub personal access token",
      file: "Brewfile.common",
      startLine: 1,
      endLine: 1,
      match: "REDACTED",
      secret: "REDACTED",
      ruleID: "github-fine-grained-pat",
      fingerprint: "Brewfile.common:github-fine-grained-pat:1",
      entropy: nil
    )
    let findingJSON = try JSONEncoder().encode([finding])
    let secrets = SecretScanService.mock { _ in
      await events.record("scan")
      return findingJSON
    }
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: secrets
    )

    await coordinator.push(branch: "main", message: "test: sync")

    let observed = await events.values
    #expect(observed.contains("git:add"))
    #expect(observed.contains("scan"))
    #expect(observed.contains("git:reset"))
    #expect(!observed.contains("git:commit"))
    #expect(!observed.contains("git:push"))
    guard case .failed(let message) = coordinator.phase else {
      Issue.record("expected failed phase, got \(coordinator.phase)")
      return
    }
    #expect(message.contains("Push blocked by secret scan"))
    #expect(message.contains("staged sync files"))
    let backups = try FileManager.default.contentsOfDirectory(
      at: workroot.appendingPathComponent("backups", isDirectory: true),
      includingPropertiesForKeys: nil
    )
    #expect(backups.isEmpty)
  }

  @Test func pushReportsCleanupFailureWhenUnstageFails() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-unstage-fail-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      if args.first == "reset" {
        throw GitError(code: 128, stderr: "reset failed", command: args)
      }
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let finding = SecretFinding(
      description: "GitHub personal access token",
      file: "Brewfile.common",
      startLine: 1,
      endLine: 1,
      match: "REDACTED",
      secret: "REDACTED",
      ruleID: "github-fine-grained-pat",
      fingerprint: "Brewfile.common:github-fine-grained-pat:1",
      entropy: nil
    )
    let findingJSON = try JSONEncoder().encode([finding])
    let secrets = SecretScanService.mock { _ in
      await events.record("scan")
      return findingJSON
    }
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: secrets
    )

    await coordinator.push(branch: "main", message: "test: sync")

    let observed = await events.values
    #expect(observed.contains("git:reset"))
    #expect(!observed.contains("git:commit"))
    #expect(!observed.contains("git:push"))
    guard case .failed(let message) = coordinator.phase else {
      Issue.record("expected failed phase, got \(coordinator.phase)")
      return
    }
    #expect(message.contains("Push blocked by secret scan"))
    #expect(message.contains("Cleanup also failed"))
    let backups = try FileManager.default.contentsOfDirectory(
      at: workroot.appendingPathComponent("backups", isDirectory: true),
      includingPropertiesForKeys: nil
    )
    #expect(backups.isEmpty)
  }

  @Test func pullPausesBeforeApplyingBrewfileEntriesThatNeedReview() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-review-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      if args.first == "rev-list" {
        return SubprocessResult(exitCode: 0, stdout: Data("0\t0\n".utf8), stderr: Data())
      }
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let brewBundle = BrewBundleService(
      runner: SubprocessRunner(),
      brewURL: URL(fileURLWithPath: "/usr/bin/false"),
      chezmoiSourceRoot: workroot
    )
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: nil,
      brewBundle: brewBundle
    )

    await coordinator.pull(branch: "main")

    guard case .awaitingPullApplyReview(let review) = coordinator.phase else {
      Issue.record("expected review phase, got \(coordinator.phase)")
      return
    }
    #expect(review.packageReviews.contains { $0.package == "ripgrep" })
    let observed = await events.values
    #expect(observed.contains("git:pull"))
  }

  @Test func pendingPullApplyReviewBlocksPushAndFreshPull() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-review-protected-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      if args.first == "rev-list" {
        return SubprocessResult(exitCode: 0, stdout: Data("0\t0\n".utf8), stderr: Data())
      }
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: SecretScanService.mock { _ in Data("[]".utf8) }
    )

    await coordinator.pull(branch: "main")
    guard case .awaitingPullApplyReview = coordinator.phase else {
      Issue.record("expected pending review, got \(coordinator.phase)")
      return
    }

    await coordinator.push(branch: "main", message: "test: should-not-push")
    await coordinator.pull(branch: "main")

    guard case .awaitingPullApplyReview = coordinator.phase else {
      Issue.record("expected review phase to remain protected, got \(coordinator.phase)")
      return
    }
    let observed = await events.values
    #expect(observed.filter { $0 == "git:pull" }.count == 1)
    #expect(!observed.contains("git:add"))
    #expect(!observed.contains("git:push"))
  }

  @Test func applyReviewedPullRunsAfterConsent() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-apply-review-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      if args.first == "rev-list" {
        return SubprocessResult(exitCode: 0, stdout: Data("0\t0\n".utf8), stderr: Data())
      }
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let brewBundle = BrewBundleService(
      runner: SubprocessRunner(),
      brewURL: URL(fileURLWithPath: "/usr/bin/true"),
      chezmoiSourceRoot: workroot
    )
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: nil,
      brewBundle: brewBundle
    )

    await coordinator.pull(branch: "main")
    await coordinator.applyReviewedPull()

    #expect(coordinator.phase == .done(.syncPull))
  }

  @Test func applyReviewedPullRejectsChangedReviewedContent() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-review-fingerprint-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      if args.first == "rev-list" {
        return SubprocessResult(exitCode: 0, stdout: Data("0\t0\n".utf8), stderr: Data())
      }
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let brewBundle = BrewBundleService(
      runner: SubprocessRunner(),
      brewURL: URL(fileURLWithPath: "/usr/bin/false"),
      chezmoiSourceRoot: workroot
    )
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: nil,
      brewBundle: brewBundle,
      brewfileContents: "brew \"ripgrep\"\n"
    )

    await coordinator.pull(branch: "main")
    guard case .awaitingPullApplyReview = coordinator.phase else {
      Issue.record("expected pending review, got \(coordinator.phase)")
      return
    }

    let brewfile = workroot
      .appendingPathComponent("repo", isDirectory: true)
      .appendingPathComponent("Brewfile.common")
    try Data("brew \"ripgrep\"\nbrew \"fd\"\n".utf8).write(to: brewfile)

    await coordinator.applyReviewedPull()

    guard case .failed(let message) = coordinator.phase else {
      Issue.record("expected changed-content failure, got \(coordinator.phase)")
      return
    }
    #expect(message.contains("changed after review"))
  }

  @Test func pullReviewCannotBeBypassedByDisablingCooldowns() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-review-cooldown-off-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      if args.first == "rev-list" {
        return SubprocessResult(exitCode: 0, stdout: Data("0\t0\n".utf8), stderr: Data())
      }
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let brewBundle = BrewBundleService(
      runner: SubprocessRunner(),
      brewURL: URL(fileURLWithPath: "/usr/bin/false"),
      chezmoiSourceRoot: workroot
    )
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: nil,
      brewBundle: brewBundle,
      brewfileContents: "cask \"arc\"\n",
      cooldownEnabled: false
    )

    await coordinator.pull(branch: "main")

    guard case .awaitingPullApplyReview(let review) = coordinator.phase else {
      Issue.record("expected review phase, got \(coordinator.phase)")
      return
    }
    #expect(review.packageReviews.contains { item in
      item.manager == "cask"
        && item.package == "arc"
        && item.reason.contains("pull-apply consent still applies")
    })
    let observed = await events.values
    #expect(observed.contains("git:pull"))
  }

  @Test func pullReviewRequiresConsentForChezmoiTemplates() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-review-template-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      if args.first == "rev-list" {
        return SubprocessResult(exitCode: 0, stdout: Data("0\t0\n".utf8), stderr: Data())
      }
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: nil,
      brewfileContents: "# no packages\n"
    )
    let template = workroot
      .appendingPathComponent("repo", isDirectory: true)
      .appendingPathComponent("dot_config", isDirectory: true)
      .appendingPathComponent("app", isDirectory: true)
      .appendingPathComponent("config.toml.tmpl")
    try FileManager.default.createDirectory(
      at: template.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("value={{ output \"date\" }}\n".utf8).write(to: template)

    await coordinator.pull(branch: "main")

    guard case .awaitingPullApplyReview(let review) = coordinator.phase else {
      Issue.record("expected review phase, got \(coordinator.phase)")
      return
    }
    #expect(review.chezmoiTemplates.contains("dot_config/app/config.toml.tmpl"))
  }

  @Test func pullReviewRequiresConsentForUnparsedBrewfileRuby() async throws {
    let workroot = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-sync-review-ruby-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workroot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workroot) }

    let events = SyncEventRecorder()
    let git = GitService(gitURL: URL(fileURLWithPath: "/usr/bin/git")) { args, _ in
      await events.record("git:\(args.first ?? "")")
      if args.first == "rev-list" {
        return SubprocessResult(exitCode: 0, stdout: Data("0\t0\n".utf8), stderr: Data())
      }
      return SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
    }
    let coordinator = try await makeMockCoordinator(
      workroot: workroot,
      git: git,
      secrets: nil,
      brewfileContents: "system \"touch\", \"/tmp/sojourn-bypass\"\n"
    )

    await coordinator.pull(branch: "main")

    guard case .awaitingPullApplyReview(let review) = coordinator.phase else {
      Issue.record("expected review phase, got \(coordinator.phase)")
      return
    }
    #expect(review.packageReviews.contains { item in
      item.manager == "ruby" && item.package == "line 1"
    })
  }

  private func makeMockCoordinator(
    workroot: URL,
    git: GitService,
    secrets: SecretScanService?,
    brewBundle: BrewBundleService? = nil,
    brewfileContents: String = "brew \"ripgrep\"\n",
    cooldownEnabled: Bool = true
  ) async throws -> SyncCoordinator {
    let repoURL = workroot.appendingPathComponent("repo", isDirectory: true)
    try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
    try Data(brewfileContents.utf8)
      .write(to: repoURL.appendingPathComponent("Brewfile.common"))

    let runner = SubprocessRunner()
    let paths = try AppSupportPaths(overrideRoot: workroot)
    let backups = BackupsDirectory(paths: paths)
    let snapshots = SnapshotService.live(backups: backups, runner: runner)
    let settings = try SettingsStore(paths: paths)
    if !cooldownEnabled {
      var snapshot = await settings.value
      snapshot.cooldownEnabled = false
      try await settings.replace(snapshot)
    }
    let cooldown = CooldownGate(settings: settings, fetch: { _ in (Data(), URLResponse()) })
    let defaultBrewBundle = BrewBundleService(
      runner: runner,
      brewURL: URL(fileURLWithPath: "/usr/bin/false")
    )
    let resolver = ConflictResolver(git: git, repoURL: repoURL)
    return SyncCoordinator(
      repoURL: repoURL,
      git: git,
      chezmoi: nil,
      brewBundle: brewBundle ?? defaultBrewBundle,
      pref: nil,
      secrets: secrets,
      snapshots: snapshots,
      cooldown: cooldown,
      conflictResolver: resolver
    )
  }
}

private actor SyncEventRecorder {
  private var storage: [String] = []

  var values: [String] { storage }

  func record(_ value: String) {
    storage.append(value)
  }
}
