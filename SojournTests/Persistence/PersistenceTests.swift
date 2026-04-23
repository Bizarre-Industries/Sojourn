import Foundation
import Testing
@testable import Sojourn

struct SojournFileCodecTests {
  @Test func decodesSimpleTable() throws {
    let input = """
    remote = "git@github.com:user/sojourn-data.git"
    cooldown_days = 7

    [package]
    id = "ripgrep"
    version = "14.1.0"
    pinned = true
    """
    let codec = SojournFileCodec()
    let out = try codec.decode(input)
    #expect(out["remote"]?.stringValue == "git@github.com:user/sojourn-data.git")
    #expect(out["cooldown_days"]?.intValue == 7)
    let pkg = out["package"]?.tableValue
    #expect(pkg?["id"]?.stringValue == "ripgrep")
    #expect(pkg?["version"]?.stringValue == "14.1.0")
    #expect(pkg?["pinned"]?.boolValue == true)
  }

  @Test func decodesArrayOfTables() throws {
    let input = """
    [[packages]]
    id = "ripgrep"
    version = "14.1.0"

    [[packages]]
    id = "fd"
    version = "9.0.0"
    """
    let codec = SojournFileCodec()
    let out = try codec.decode(input)
    guard case .array(let items) = out["packages"] ?? .integer(0) else {
      Issue.record("expected .array")
      return
    }
    #expect(items.count == 2)
    #expect(items[0].tableValue?["id"]?.stringValue == "ripgrep")
    #expect(items[1].tableValue?["id"]?.stringValue == "fd")
  }

  @Test func stripsCommentsOutsideStrings() throws {
    let input = """
    # header comment
    path = "/tmp/with # hash"  # trailing comment
    """
    let out = try SojournFileCodec().decode(input)
    #expect(out["path"]?.stringValue == "/tmp/with # hash")
  }

  @Test func decodesInlineArrayOfStrings() throws {
    let input = """
    tags = ["a", "b", "c"]
    """
    let out = try SojournFileCodec().decode(input)
    #expect(out["tags"]?.arrayValue?.count == 3)
    #expect(out["tags"]?.arrayValue?[1].stringValue == "b")
  }

  @Test func encodeRoundTripsSimple() throws {
    let codec = SojournFileCodec()
    let input: [String: TOMLValue] = [
      "name": .string("sojourn"),
      "cooldown_days": .integer(7),
      "tags": .array([.string("a"), .string("b")]),
      "package": .table([
        "id": .string("ripgrep"),
        "version": .string("14.1.0"),
      ]),
    ]
    let text = codec.encode(input)
    let reparsed = try codec.decode(text)
    #expect(reparsed["name"]?.stringValue == "sojourn")
    #expect(reparsed["cooldown_days"]?.intValue == 7)
    #expect(reparsed["package"]?.tableValue?["id"]?.stringValue == "ripgrep")
  }

  @Test func rejectsMissingEquals() {
    let input = "just a line without equals"
    do {
      _ = try SojournFileCodec().decode(input)
      Issue.record("expected TOMLError.syntax")
    } catch is TOMLError {
      // expected
    } catch {
      Issue.record("unexpected error: \(error)")
    }
  }
}

struct AppSupportPathsTests {
  @Test func createsAllDirsUnderOverride() throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let paths = try AppSupportPaths(overrideRoot: tmp)
    for url in [paths.root, paths.backups, paths.logs, paths.cache, paths.config, paths.bin] {
      var isDir: ObjCBool = false
      #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir))
      #expect(isDir.boolValue)
    }
  }
}

struct BackupsDirectoryTests {
  @Test func createsNamedSnapshotDir() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let paths = try AppSupportPaths(overrideRoot: tmp)
    let backups = BackupsDirectory(paths: paths)
    let url = try await backups.createSnapshotDir(for: .syncPush)
    #expect(url.lastPathComponent.contains("sync.push"))
    #expect(FileManager.default.fileExists(atPath: url.path))
  }

  @Test func listReturnsNewestFirst() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let paths = try AppSupportPaths(overrideRoot: tmp)
    let backups = BackupsDirectory(paths: paths)
    let u1 = try await backups.createSnapshotDir(for: .dotfileApply)
    try await Task.sleep(nanoseconds: 50_000_000)
    let u2 = try await backups.createSnapshotDir(for: .syncPull)

    let list = try await backups.list()
    #expect(list.count == 2)
    #expect(list.first?.lastPathComponent == u2.lastPathComponent)
    #expect(list.last?.lastPathComponent == u1.lastPathComponent)
  }
}

struct DeletionsDBTests {
  @Test func insertAndListRoundTrips() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("deletions-\(UUID().uuidString).sqlite", isDirectory: false)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let db = try DeletionsDB(url: tmp)
    _ = try await db.record(
      path: "/Users/u/Library/Caches/com.oldapp",
      reason: "orphan-cache"
    )
    _ = try await db.record(
      path: "/Users/u/Library/Preferences/com.gone.plist",
      reason: "orphan-preference",
      rollbackPossible: false
    )
    let count = try await db.count()
    #expect(count == 2)

    let rows = try await db.list()
    #expect(rows.count == 2)
    #expect(rows[0].path.contains("com.gone.plist") || rows[1].path.contains("com.gone.plist"))
    #expect(rows.contains(where: { $0.reason == "orphan-cache" }))

    await db.close()
  }
}

struct SettingsStoreTests {
  @Test func emptySettingsAreDefaulted() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let paths = try AppSupportPaths(overrideRoot: tmp)
    let store = try SettingsStore(paths: paths)
    let s = await store.value
    #expect(s.cooldownEnabled == true)
    #expect(s.dryRunByDefault == true)
    #expect(s.toolLocations.isEmpty)
  }

  @Test func mutatePersists() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let paths = try AppSupportPaths(overrideRoot: tmp)
    let store = try SettingsStore(paths: paths)

    try await store.mutate { s in
      s.cooldownEnabled = false
      s.remoteRepoURL = "git@example.invalid:u/sojourn-data.git"
      s.lastSyncTime = Date(timeIntervalSince1970: 1713895200)
    }

    let store2 = try SettingsStore(paths: paths)
    let s2 = await store2.value
    #expect(s2.cooldownEnabled == false)
    #expect(s2.remoteRepoURL == "git@example.invalid:u/sojourn-data.git")
    #expect(s2.lastSyncTime?.timeIntervalSince1970 == 1713895200)
  }

  @Test func tierAppliesOverrides() {
    var s = Settings.empty
    s.cooldownOverrides["brew"] = .c
    #expect(s.tier(for: "brew") == .c)
    #expect(s.tier(for: "npm") == .e)
  }
}

struct ModelCodableSanityTests {
  @Test func historyEntryRoundTrip() throws {
    let entry = HistoryEntry(
      kind: .syncPush,
      description: "pushed 3 updates",
      timestamp: Date(timeIntervalSince1970: 1713895200)
    )
    let enc = JSONEncoder()
    enc.dateEncodingStrategy = .iso8601
    let data = try enc.encode(entry)
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    let back = try dec.decode(HistoryEntry.self, from: data)
    #expect(back.kind == .syncPush)
    #expect(back.description == "pushed 3 updates")
    #expect(back.timestamp.timeIntervalSince1970 == 1713895200)
  }

  @Test func tierIsCoded() {
    #expect(AutoUpdateTier.e.cooldownDays == 14)
    #expect(AutoUpdateTier.a.canAutoSilent == true)
    #expect(AutoUpdateTier.e.canAutoSilent == false)
    #expect(ManagerTier.tier(for: "npm") == .e)
    #expect(ManagerTier.tier(for: "completely-unknown") == .c)
  }
}
