// HistoryDBTests — smoke coverage for the SQLite-backed history log.
// Audit §3.1.6 / §3.3.1. v0.1.0 ships one round-trip + retention prune
// test; full coverage lands in v0.2.0 alongside the SettingsStore.history
// removal.

import Foundation
@testable import Sojourn
import Testing

@Suite("HistoryDB")
struct HistoryDBTests {
  private func makeTempURL() -> URL {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("sojourn-historydb-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("history.sqlite")
  }

  @Test("insert + list round-trip")
  func roundTrip() async throws {
    let db = try HistoryDB(url: makeTempURL())
    let entry = HistoryEntry(
      id: UUID(),
      kind: .syncPush,
      description: "first push",
      timestamp: Date()
    )
    try await db.insert(entry)
    let rows = try await db.list(limit: 10)
    #expect(rows.count == 1)
    #expect(rows.first?.id == entry.id)
    #expect(rows.first?.kind == .syncPush)
  }

  @Test("prune drops entries older than retention horizon")
  func prunesOldEntries() async throws {
    let db = try HistoryDB(url: makeTempURL())
    let now = Date()
    let stale = HistoryEntry(
      id: UUID(),
      kind: .syncPull,
      description: "stale",
      timestamp: now.addingTimeInterval(-60 * 24 * 3600) // 60d ago
    )
    let fresh = HistoryEntry(
      id: UUID(),
      kind: .syncPull,
      description: "fresh",
      timestamp: now
    )
    try await db.insert(stale)
    try await db.insert(fresh)
    try await db.prune(now: now)
    let rows = try await db.list(limit: 10)
    #expect(rows.count == 1)
    #expect(rows.first?.id == fresh.id)
  }
}
