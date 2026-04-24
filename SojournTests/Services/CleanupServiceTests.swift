import Foundation
import Testing
@testable import Sojourn

struct CleanupServiceTests {
  @Test func loadBundledRegistryPopulatesOwners() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-cleanup-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    let dbURL = tmp.appendingPathComponent("deletions.sqlite")
    let db = try DeletionsDB(url: dbURL)
    defer { Task { await db.close() } }

    let svc = CleanupService(deletionsDB: db)
    await svc.loadBundledRegistry()
    let owners = await svc.owners()
    #expect(!owners.isEmpty)
    #expect(owners.contains(where: { $0.path == ".zshrc" }))
  }

  @Test func scanFindsUnmanagedDotfiles() async throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("sojourn-cleanup-home-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    try Data("x".utf8).write(to: tmp.appendingPathComponent(".zshrc"))
    try Data("x".utf8).write(to: tmp.appendingPathComponent(".totallyfakedotfile"))

    let dbURL = tmp.appendingPathComponent("deletions.sqlite")
    let db = try DeletionsDB(url: dbURL)
    defer { Task { await db.close() } }

    let svc = CleanupService(deletionsDB: db)
    await svc.loadBundledRegistry()

    let candidates = await svc.scan(homeURL: tmp)
    #expect(candidates.contains(where: { $0.path.lastPathComponent == ".totallyfakedotfile" }))
    #expect(!candidates.contains(where: { $0.path.lastPathComponent == ".zshrc" }))
  }
}
