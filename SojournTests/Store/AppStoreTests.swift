import Foundation
@testable import Sojourn
import Testing

@MainActor
struct AppStoreTests {
  @Test func advisorySnapshotRefreshLoadsCacheWithoutBrewInvocation() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-store-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let paths = try AppSupportPaths(overrideRoot: tmp)
    let snapshot = AdvisorySnapshot(
      advisories: [
        AdvisoryReference(
          id: "GHSA-test-cache",
          feed: .osv,
          severity: .high,
          summary: "Cached test advisory.",
          publishedAt: Date(),
          modifiedAt: Date(),
          referenceURL: URL(string: "https://example.invalid/advisory")
        )
      ],
      freshness: .unavailable,
      lastSuccessAt: Date(),
      lastAttemptAt: Date(),
      cacheKeySHA256: "abc123"
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(snapshot)
      .write(to: paths.cache.appendingPathComponent("advisories.json"), options: .atomic)

    let (store, deletions) = try makeStore(paths: paths)
    await store.refreshAdvisorySnapshot(force: true)

    #expect(store.advisorySnapshot.advisories.map(\.id) == ["GHSA-test-cache"])
    #expect(store.advisorySnapshot.freshness == .fresh)
    #expect(store.advisoryMessage == "Reloaded cached advisory snapshot.")
    await deletions.close()
  }

  @Test func advisorySnapshotRefreshReportsMissingCache() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-store-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let (store, deletions) = try makeStore(paths: AppSupportPaths(overrideRoot: tmp))
    await store.refreshAdvisorySnapshot(force: true)

    #expect(store.advisorySnapshot.advisories.isEmpty)
    #expect(store.advisorySnapshot.freshness == .unavailable)
    #expect(store.advisoryMessage ==
      "No cached advisory snapshot. Run an advisory scan after Homebrew vulnerability data is configured, then refresh this pane."
    )
    await deletions.close()
  }

  @Test func brewfileRefreshIsTrackedAsJobRunnerActivity() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-store-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let (store, deletions) = try makeStore(paths: AppSupportPaths(overrideRoot: tmp))
    await store.refreshBrewfile(force: true)

    let job = store.jobRunner.jobs.first { $0.label == "Refresh Brewfile" }
    #expect(job != nil)
    #expect(job?.state.isTerminal == true)
    guard case .failed = job?.state else {
      Issue.record("expected failed tracked Brewfile job, got \(String(describing: job?.state))")
      await deletions.close()
      return
    }
    await deletions.close()
  }

  @Test func concurrentBrewfileRefreshCoalescesIntoOneJob() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-store-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let brewURL = try makeFakeBrewScript(in: tmp)
    let (store, deletions) = try makeStore(
      paths: AppSupportPaths(overrideRoot: tmp),
      brewURL: brewURL
    )

    async let first: Void = store.refreshBrewfile(force: true)
    async let second: Void = store.refreshBrewfile(force: true)
    _ = await (first, second)

    let jobs = store.jobRunner.jobs.filter { $0.label == "Refresh Brewfile" }
    #expect(jobs.count == 1)
    #expect(store.brewfile != nil)
    await deletions.close()
  }

  @Test func concurrentContainerRefreshCoalescesWithoutSyntheticJob() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-store-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let (store, deletions) = try makeStore(paths: AppSupportPaths(overrideRoot: tmp))

    async let first: Void = store.refreshContainers(forceRescan: false)
    async let second: Void = store.refreshContainers(forceRescan: false)
    _ = await (first, second)

#if DEBUG
    #expect(store.debugContainersRefreshStarts == 1)
#endif
    #expect(store.jobRunner.jobs.allSatisfy { job in
      job.label != "Refresh Containers" && job.label != "Rescan Containers"
    })
    await deletions.close()
  }

  private func makeStore(
    paths: AppSupportPaths,
    brewURL: URL = URL(fileURLWithPath: "/usr/bin/false")
  ) throws -> (AppStore, DeletionsDB) {
    let runner = SubprocessRunner()
    let settings = try SettingsStore(paths: paths)
    let deletions = try DeletionsDB(
      url: paths.config.appendingPathComponent("deletions.sqlite", isDirectory: false)
    )
    let brewBundle = BrewBundleService(
      runner: runner,
      brewURL: brewURL
    )

    let store = AppStore(
      paths: paths,
      settingsStore: settings,
      deletionsDB: deletions,
      historyDB: nil,
      brewBundle: brewBundle,
      brewURL: brewURL,
      git: nil,
      chezmoi: nil,
      secrets: nil
    )
    return (store, deletions)
  }

  private func makeFakeBrewScript(in root: URL) throws -> URL {
    let script = root.appendingPathComponent("fake-brew")
    let body = """
    #!/bin/sh
    sleep 0.2
    printf 'brew "ripgrep"\\n'
    """
    try body.write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: script.path
    )
    return script
  }
}
