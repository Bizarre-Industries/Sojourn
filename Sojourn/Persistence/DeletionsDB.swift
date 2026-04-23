// Sojourn — DeletionsDB
//
// Append-only audit log of every file/dir Sojourn has moved to Trash. No
// row represents an `rm`; Sojourn never calls `rm`. Backed by SQLite
// (sqlite3, Apple-shipped) so we get durable, crash-safe writes without a
// new dependency. See docs/ARCHITECTURE.md §10 and docs/SECURITY.md.

import Foundation
import SQLite3

internal struct DeletionRecord: Sendable, Hashable, Identifiable {
  internal let id: Int64
  internal let path: String
  internal let reason: String?
  internal let trashedAt: Date
  internal let rollbackPossible: Bool
}

internal enum DeletionsDBError: Error, Sendable, Equatable {
  case openFailed(Int32)
  case prepareFailed(Int32, String)
  case stepFailed(Int32, String)
  case bindFailed(Int32)
}

/// SQLite's `SQLITE_TRANSIENT` bind disposition — forces the engine to
/// copy the text. Apple headers expose it only as a C-cast macro.
private let SQLITE_TRANSIENT = unsafeBitCast(
  OpaquePointer(bitPattern: -1),
  to: sqlite3_destructor_type.self
)

internal actor DeletionsDB {
  private var db: OpaquePointer?
  private let url: URL

  internal init(url: URL) throws {
    self.url = url
    var handle: OpaquePointer?
    let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
    let rc = sqlite3_open_v2(url.path, &handle, flags, nil)
    if rc != SQLITE_OK {
      if let handle { sqlite3_close_v2(handle) }
      throw DeletionsDBError.openFailed(rc)
    }
    self.db = handle
    try Self.createSchema(handle!)
  }

  /// Close the underlying sqlite handle. Prefer calling this explicitly
  /// from tests; in production the process exits and the kernel reclaims
  /// the FD.
  internal func close() {
    if let db {
      sqlite3_close_v2(db)
      self.db = nil
    }
  }

  private static func createSchema(_ db: OpaquePointer) throws {
    let ddl = """
    CREATE TABLE IF NOT EXISTS deletions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      path TEXT NOT NULL,
      reason TEXT,
      trashed_at REAL NOT NULL,
      rollback_possible INTEGER NOT NULL DEFAULT 1
    );
    CREATE INDEX IF NOT EXISTS idx_deletions_trashed_at ON deletions(trashed_at);
    """
    var err: UnsafeMutablePointer<CChar>?
    let rc = sqlite3_exec(db, ddl, nil, nil, &err)
    if rc != SQLITE_OK {
      let msg = err.map { String(cString: $0) } ?? "?"
      sqlite3_free(err)
      throw DeletionsDBError.stepFailed(rc, msg)
    }
  }

  @discardableResult
  internal func record(path: String, reason: String?, rollbackPossible: Bool = true) throws -> Int64 {
    guard let db else { throw DeletionsDBError.openFailed(SQLITE_MISUSE) }
    let sql = """
    INSERT INTO deletions (path, reason, trashed_at, rollback_possible)
    VALUES (?, ?, ?, ?)
    """
    var stmt: OpaquePointer?
    let prep = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    if prep != SQLITE_OK {
      throw DeletionsDBError.prepareFailed(prep, String(cString: sqlite3_errmsg(db)))
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, path, -1, SQLITE_TRANSIENT)
    if let reason {
      sqlite3_bind_text(stmt, 2, reason, -1, SQLITE_TRANSIENT)
    } else {
      sqlite3_bind_null(stmt, 2)
    }
    sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
    sqlite3_bind_int(stmt, 4, rollbackPossible ? 1 : 0)

    let step = sqlite3_step(stmt)
    if step != SQLITE_DONE {
      throw DeletionsDBError.stepFailed(step, String(cString: sqlite3_errmsg(db)))
    }
    return sqlite3_last_insert_rowid(db)
  }

  internal func list(limit: Int = 1000) throws -> [DeletionRecord] {
    guard let db else { throw DeletionsDBError.openFailed(SQLITE_MISUSE) }
    let sql = """
    SELECT id, path, reason, trashed_at, rollback_possible
    FROM deletions
    ORDER BY trashed_at DESC
    LIMIT ?
    """
    var stmt: OpaquePointer?
    let prep = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    if prep != SQLITE_OK {
      throw DeletionsDBError.prepareFailed(prep, String(cString: sqlite3_errmsg(db)))
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_int(stmt, 1, Int32(limit))

    var rows: [DeletionRecord] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      let id = sqlite3_column_int64(stmt, 0)
      let path = String(cString: sqlite3_column_text(stmt, 1))
      let reason: String? = sqlite3_column_type(stmt, 2) == SQLITE_NULL
        ? nil
        : String(cString: sqlite3_column_text(stmt, 2))
      let trashedAt = sqlite3_column_double(stmt, 3)
      let rollback = sqlite3_column_int(stmt, 4) != 0
      rows.append(DeletionRecord(
        id: id,
        path: path,
        reason: reason,
        trashedAt: Date(timeIntervalSince1970: trashedAt),
        rollbackPossible: rollback
      ))
    }
    return rows
  }

  internal func count() throws -> Int {
    guard let db else { throw DeletionsDBError.openFailed(SQLITE_MISUSE) }
    var stmt: OpaquePointer?
    sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM deletions", -1, &stmt, nil)
    defer { sqlite3_finalize(stmt) }
    if sqlite3_step(stmt) == SQLITE_ROW {
      return Int(sqlite3_column_int64(stmt, 0))
    }
    return 0
  }
}
