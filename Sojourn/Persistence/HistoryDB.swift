// Sojourn — HistoryDB
//
// SQLite-backed history log. Audit §3.3.1 + §3.1.6 — replace the flat
// `[HistoryEntry]` in `SettingsStore` with a queryable, durable store.
// 30-day retention per `docs/process/open-questions.md` §5 default.
//
// Pattern mirrors `DeletionsDB.swift`: SQLite via Apple-shipped `sqlite3`,
// actor-isolated handle, fully-mutexed open flags.

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(
  OpaquePointer(bitPattern: -1),
  to: sqlite3_destructor_type.self
)

internal enum HistoryDBError: Error, Sendable, Equatable {
  case openFailed(Int32)
  case prepareFailed(Int32, String)
  case stepFailed(Int32, String)
}

internal actor HistoryDB {
  private var db: OpaquePointer?
  private let url: URL

  /// Retention horizon — entries older than this are pruned by `prune()`.
  internal static let retentionDays: Double = 30

  internal init(url: URL) throws {
    self.url = url
    var handle: OpaquePointer?
    let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
    let rc = sqlite3_open_v2(url.path, &handle, flags, nil)
    if rc != SQLITE_OK {
      if let handle { sqlite3_close_v2(handle) }
      throw HistoryDBError.openFailed(rc)
    }
    self.db = handle
    try Self.createSchema(handle!)
  }

  internal func close() {
    if let db {
      sqlite3_close_v2(db)
      self.db = nil
    }
  }

  // MARK: - Schema

  private static func createSchema(_ db: OpaquePointer) throws {
    let sql = """
      CREATE TABLE IF NOT EXISTS history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL,
        description TEXT NOT NULL,
        timestamp REAL NOT NULL,
        sha TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_history_timestamp ON history(timestamp);
      """
    var err: UnsafeMutablePointer<CChar>?
    let rc = sqlite3_exec(db, sql, nil, nil, &err)
    if rc != SQLITE_OK {
      let msg = err.map { String(cString: $0) } ?? "(no message)"
      sqlite3_free(err)
      throw HistoryDBError.stepFailed(rc, msg)
    }
  }

  // MARK: - Insert

  internal func insert(_ entry: HistoryEntry, sha: String? = nil) throws {
    guard let db else { return }
    let sql = "INSERT OR IGNORE INTO history(entry_id, kind, description, timestamp, sha) VALUES(?,?,?,?,?);"
    var stmt: OpaquePointer?
    let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    guard rc == SQLITE_OK, let stmt else {
      let msg = String(cString: sqlite3_errmsg(db))
      throw HistoryDBError.prepareFailed(rc, msg)
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, entry.id.uuidString, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, entry.kind.rawValue, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 3, entry.description, -1, SQLITE_TRANSIENT)
    sqlite3_bind_double(stmt, 4, entry.timestamp.timeIntervalSince1970)
    if let sha {
      sqlite3_bind_text(stmt, 5, sha, -1, SQLITE_TRANSIENT)
    } else {
      sqlite3_bind_null(stmt, 5)
    }
    let stepRC = sqlite3_step(stmt)
    if stepRC != SQLITE_DONE {
      let msg = String(cString: sqlite3_errmsg(db))
      throw HistoryDBError.stepFailed(stepRC, msg)
    }
  }

  // MARK: - Query

  internal func list(limit: Int = 200) throws -> [HistoryEntry] {
    guard let db else { return [] }
    let sql = "SELECT entry_id, kind, description, timestamp FROM history ORDER BY timestamp DESC LIMIT ?;"
    var stmt: OpaquePointer?
    let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    guard rc == SQLITE_OK, let stmt else {
      let msg = String(cString: sqlite3_errmsg(db))
      throw HistoryDBError.prepareFailed(rc, msg)
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_int(stmt, 1, Int32(limit))

    var rows: [HistoryEntry] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      guard let idC = sqlite3_column_text(stmt, 0),
            let kindC = sqlite3_column_text(stmt, 1),
            let descC = sqlite3_column_text(stmt, 2) else { continue }
      let entryID = String(cString: idC)
      let kindRaw = String(cString: kindC)
      let desc = String(cString: descC)
      let ts = sqlite3_column_double(stmt, 3)
      guard let uuid = UUID(uuidString: entryID),
            let kind = HistoryEntry.Kind(rawValue: kindRaw) else { continue }
      rows.append(HistoryEntry(
        id: uuid,
        kind: kind,
        description: desc,
        timestamp: Date(timeIntervalSince1970: ts)
      ))
    }
    return rows
  }

  // MARK: - Prune

  /// Drop entries older than `HistoryDB.retentionDays`.
  internal func prune(now: Date = Date()) throws {
    guard let db else { return }
    let cutoff = now.timeIntervalSince1970 - (HistoryDB.retentionDays * 24 * 60 * 60)
    let sql = "DELETE FROM history WHERE timestamp < ?;"
    var stmt: OpaquePointer?
    let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    guard rc == SQLITE_OK, let stmt else {
      let msg = String(cString: sqlite3_errmsg(db))
      throw HistoryDBError.prepareFailed(rc, msg)
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_double(stmt, 1, cutoff)
    let stepRC = sqlite3_step(stmt)
    if stepRC != SQLITE_DONE {
      let msg = String(cString: sqlite3_errmsg(db))
      throw HistoryDBError.stepFailed(stepRC, msg)
    }
  }
}
