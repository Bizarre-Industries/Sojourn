// Sojourn — MasHelper executable trust validation

import Darwin
import Foundation

internal enum MasExecutableTrustError: Error, Sendable, Equatable, CustomStringConvertible {
  case notFound(String)
  case notRegularFile(String)
  case notExecutable(String)
  case notRootOwned(String, uid_t)
  case writableByGroupOrOther(String, mode_t)

  internal var description: String {
    switch self {
    case .notFound(let path):
      return "\(path) was not found"
    case .notRegularFile(let path):
      return "\(path) is not a regular file"
    case .notExecutable(let path):
      return "\(path) is not executable"
    case .notRootOwned(let path, let owner):
      return "\(path) is owned by uid \(owner), not root"
    case .writableByGroupOrOther(let path, let mode):
      return "\(path) is writable by group/other (mode \(String(mode, radix: 8)))"
    }
  }
}

internal enum MasExecutableValidator {
  internal static func trustedExecutableURL(at path: String) throws -> URL {
    let original = URL(fileURLWithPath: path).standardizedFileURL
    try validatePathComponents(for: original)

    let resolved = original
      .resolvingSymlinksInPath()
      .standardizedFileURL
    try validatePathComponents(for: resolved)
    try validateExecutable(at: resolved.path)
    return resolved
  }

  private static func validatePathComponents(for url: URL) throws {
    var current = "/"
    try validateRootOwnedPath(current)

    for component in url.deletingLastPathComponent().pathComponents.dropFirst() {
      current = (current as NSString).appendingPathComponent(component)
      try validateRootOwnedPath(current)
    }
  }

  private static func validateExecutable(at path: String) throws {
    let st = try statInfo(path)
    guard (st.st_mode & S_IFMT) == S_IFREG else {
      throw MasExecutableTrustError.notRegularFile(path)
    }
    try validateRootOwned(path, stat: st)
    guard access(path, X_OK) == 0 else {
      throw MasExecutableTrustError.notExecutable(path)
    }
  }

  private static func validateRootOwnedPath(_ path: String) throws {
    try validateRootOwned(path, stat: try statInfo(path))
  }

  private static func validateRootOwned(_ path: String, stat st: stat) throws {
    guard st.st_uid == 0 else {
      throw MasExecutableTrustError.notRootOwned(path, st.st_uid)
    }
    let unsafeWriteBits = st.st_mode & (S_IWGRP | S_IWOTH)
    guard unsafeWriteBits == 0 else {
      throw MasExecutableTrustError.writableByGroupOrOther(path, st.st_mode)
    }
  }

  private static func statInfo(_ path: String) throws -> stat {
    var st = stat()
    guard stat(path, &st) == 0 else {
      throw MasExecutableTrustError.notFound(path)
    }
    return st
  }
}
