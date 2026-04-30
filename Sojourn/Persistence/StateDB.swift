// Sojourn — StateDB
//
// SQLite mirror of `chezmoi state` buckets. Audit §2.2.8 + §3.1.6.
// Lets Sojourn force-rerun a `run_once_` script or skip a re-run that
// chezmoi believes is needed.
//
// Mirrors chezmoi's two buckets: `scriptState` (run-once script keys)
// and `entryState` (managed entry checksums). Stage 11 wires reads /
// writes to/from `chezmoi state get/set/delete`.

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(
  OpaquePointer(bitPattern: -1),
  to: sqlite3_destructor_type.self
)

internal enum StateDBError: Error, Sendable, Equatable {
  case openFailed(Int32)
  case prepareFailed(Int32, String)
  case stepFailed(Int32, String)
}

internal actor StateDB {
  private var db: OpaquePointer?
  private let url: URL

  internal init(url: URL) throws {
    self.url = url
    var handle: OpaquePointer?
    let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
    let rc = sqlite3_open_v2(url.path, &handle, flags, nil)
    if rc != SQLITE_OK {
      if let handle { sqlite3_close_v2(handle) }
      throw StateDBError.openFailed(rc)
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

  private static func createSchema(_ db: OpaquePointer) throws {
    let sql = """
      CREATE TABLE IF NOT EXISTS state(
        bucket TEXT NOT NULL,
        key TEXT NOT NULL,
        value BLOB NOT NULL,
        updated_at REAL NOT NULL,
        PRIMARY KEY(bucket, key)
      );
      """
    var err: UnsafeMutablePointer<CChar>?
    let rc = sqlite3_exec(db, sql, nil, nil, &err)
    if rc != SQLITE_OK {
      let msg = err.map { String(cString: $0) } ?? "(no message)"
      sqlite3_free(err)
      throw StateDBError.stepFailed(rc, msg)
    }
  }

  // MARK: - Get / set / delete

  internal func get(bucket: String, key: String) throws -> Data? {
    guard let db else { return nil }
    let sql = "SELECT value FROM state WHERE bucket = ? AND key = ? LIMIT 1;"
    var stmt: OpaquePointer?
    let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    guard rc == SQLITE_OK, let stmt else {
      throw StateDBError.prepareFailed(rc, String(cString: sqlite3_errmsg(db)))
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, bucket, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, key, -1, SQLITE_TRANSIENT)
    if sqlite3_step(stmt) == SQLITE_ROW {
      if let blob = sqlite3_column_blob(stmt, 0) {
        let len = Int(sqlite3_column_bytes(stmt, 0))
        return Data(bytes: blob, count: len)
      }
    }
    return nil
  }

  internal func set(bucket: String, key: String, value: Data, now: Date = Date()) throws {
    guard let db else { return }
    let sql = "INSERT OR REPLACE INTO state(bucket, key, value, updated_at) VALUES(?,?,?,?);"
    var stmt: OpaquePointer?
    let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    guard rc == SQLITE_OK, let stmt else {
      throw StateDBError.prepareFailed(rc, String(cString: sqlite3_errmsg(db)))
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, bucket, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, key, -1, SQLITE_TRANSIENT)
    value.withUnsafeBytes { buf in
      _ = sqlite3_bind_blob(stmt, 3, buf.baseAddress, Int32(buf.count), SQLITE_TRANSIENT)
    }
    sqlite3_bind_double(stmt, 4, now.timeIntervalSince1970)
    let stepRC = sqlite3_step(stmt)
    if stepRC != SQLITE_DONE {
      throw StateDBError.stepFailed(stepRC, String(cString: sqlite3_errmsg(db)))
    }
  }

  internal func delete(bucket: String, key: String) throws {
    guard let db else { return }
    let sql = "DELETE FROM state WHERE bucket = ? AND key = ?;"
    var stmt: OpaquePointer?
    let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    guard rc == SQLITE_OK, let stmt else {
      throw StateDBError.prepareFailed(rc, String(cString: sqlite3_errmsg(db)))
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, bucket, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, key, -1, SQLITE_TRANSIENT)
    let stepRC = sqlite3_step(stmt)
    if stepRC != SQLITE_DONE {
      throw StateDBError.stepFailed(stepRC, String(cString: sqlite3_errmsg(db)))
    }
  }
}
