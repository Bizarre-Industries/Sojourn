// Sojourn — PrefService
//
// Plist round-trip via `defaults export` / `defaults import` + `plutil`.
// See docs/ARCHITECTURE.md §8 (plist app preference sync strategy) and
// CLAUDE.md ("Do not symlink anything in ~/Library/Preferences").
//
// FDA canary: Sojourn is not sandboxed, but reading Container-scoped
// prefs still needs Full Disk Access. We probe with a known domain and
// surface EACCES to the UI rather than erroring silently.

import Foundation

internal enum PrefError: Error, Sendable {
  case domainNotFound(String)
  case fdaRequired(String)
  case exportFailed(String)
  case importFailed(String)
  case conversionFailed(String)
}

internal actor PrefService {
  internal typealias Runner = @Sendable (URL, [String], URL?) async throws -> SubprocessResult

  private let runCommand: Runner
  internal let defaultsURL: URL
  internal let plutilURL: URL
  internal let killallURL: URL

  internal init(
    defaultsURL: URL = URL(fileURLWithPath: "/usr/bin/defaults"),
    plutilURL: URL = URL(fileURLWithPath: "/usr/bin/plutil"),
    killallURL: URL = URL(fileURLWithPath: "/usr/bin/killall"),
    runCommand: @escaping Runner
  ) {
    self.defaultsURL = defaultsURL
    self.plutilURL = plutilURL
    self.killallURL = killallURL
    self.runCommand = runCommand
  }

  internal static func live(runner: SubprocessRunner) -> PrefService {
    PrefService(runCommand: { tool, args, cwd in
      try await runner.run(tool: tool, args: args, cwd: cwd, timeout: 30)
    })
  }

  internal static func mock(
    response: @escaping @Sendable (URL, [String]) async throws -> Data
  ) -> PrefService {
    PrefService(runCommand: { tool, args, _ in
      let data = try await response(tool, args)
      return SubprocessResult(exitCode: 0, stdout: data, stderr: Data())
    })
  }

  // MARK: - Queries

  /// Probe domain access. Returns true when `defaults read <domain>`
  /// returns zero; false when FDA is missing or the domain doesn't exist.
  internal func canAccess(domain: String) async -> Bool {
    do {
      _ = try await runCommand(defaultsURL, ["read", domain], nil)
      return true
    } catch {
      return false
    }
  }

  /// Export the given bundle-ID domain to a plist file (converted to xml1
  /// for readable git diffs). Returns the output URL.
  internal func export(domain: String, to url: URL) async throws -> URL {
    do {
      _ = try await runCommand(defaultsURL, ["export", domain, url.path], nil)
    } catch {
      throw PrefError.exportFailed("\(domain): \(error)")
    }
    do {
      _ = try await runCommand(plutilURL, ["-convert", "xml1", url.path], nil)
    } catch {
      throw PrefError.conversionFailed("\(url.path): \(error)")
    }
    return url
  }

  /// Import a plist file into the given bundle-ID domain. Nudges
  /// `cfprefsd` so running apps pick up changes.
  internal func importPlist(at url: URL, into domain: String) async throws {
    do {
      _ = try await runCommand(defaultsURL, ["import", domain, url.path], nil)
    } catch {
      throw PrefError.importFailed("\(domain): \(error)")
    }
    _ = try? await runCommand(killallURL, ["-u", NSUserName(), "cfprefsd"], nil)
  }

  /// Export several domains into a target dir, returning the URLs written.
  internal func exportAll(domains: [String], into dir: URL) async throws -> [URL] {
    var written: [URL] = []
    for d in domains {
      let target = dir.appendingPathComponent("\(d).plist", isDirectory: false)
      written.append(try await export(domain: d, to: target))
    }
    return written
  }
}
