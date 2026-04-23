// Sojourn — ToolLocator
//
// App-context `PATH` is LaunchServices-minimal; `which(1)` fails for brew on
// Apple Silicon. Per docs/BOOTSTRAP.md, we probe a hard-coded candidate list
// instead, first-hit wins, and cache the resolution in `Settings.toolLocations`
// (wired in Phase 2).

import Foundation

public struct ToolResolution: Sendable, Hashable, Codable {
  public let tool: String
  public let url: URL
  public let source: Source

  public enum Source: String, Sendable, Codable {
    /// Found via one of the hard-coded candidate paths.
    case candidate
    /// Found under `xcode-select -p`.
    case xcodeSelect
    /// Cached from a previous run.
    case cached
  }

  public init(tool: String, url: URL, source: Source) {
    self.tool = tool
    self.url = url
    self.source = source
  }
}

public actor ToolLocator {
  /// Ordered candidate directories. See docs/BOOTSTRAP.md Detection section.
  public static let candidateDirectories: [String] = [
    "/opt/homebrew/bin",
    "/opt/homebrew/sbin",
    "/usr/local/bin",
    "/usr/local/sbin",
    NSString("~/.cargo/bin").expandingTildeInPath,
    NSString("~/.local/bin").expandingTildeInPath,
    NSString("~/go/bin").expandingTildeInPath,
    NSString("~/Library/Application Support/Sojourn/bin").expandingTildeInPath,
    "/usr/bin",
    "/bin",
    "/usr/sbin",
    "/sbin",
  ]

  private let fileManager: FileManager
  private var cache: [String: ToolResolution] = [:]

  public init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  /// Seed the cache with known resolutions (e.g., restored from Settings).
  public func seed(_ resolutions: [ToolResolution]) {
    for r in resolutions { cache[r.tool] = r }
  }

  /// Return cached resolutions (for persisting to Settings).
  public func snapshot() -> [ToolResolution] {
    Array(cache.values)
  }

  /// Locate `name`. Returns `nil` if not found in any candidate dir or
  /// under the current Xcode command line tools. Caches the result.
  public func locate(_ name: String) -> ToolResolution? {
    if let cached = cache[name] {
      return cached
    }
    for dir in Self.candidateDirectories {
      let candidate = URL(fileURLWithPath: dir).appendingPathComponent(name)
      if fileManager.isExecutableFile(atPath: candidate.path) {
        let resolution = ToolResolution(tool: name, url: candidate, source: .candidate)
        cache[name] = resolution
        return resolution
      }
    }
    if let cltBin = xcodeSelectBinDir() {
      let candidate = cltBin.appendingPathComponent(name)
      if fileManager.isExecutableFile(atPath: candidate.path) {
        let resolution = ToolResolution(tool: name, url: candidate, source: .xcodeSelect)
        cache[name] = resolution
        return resolution
      }
    }
    return nil
  }

  /// Probe a list of tool names in sequence (filesystem-only; cheap).
  public func locateAll(_ names: [String]) -> [String: ToolResolution] {
    var out: [String: ToolResolution] = [:]
    for name in names {
      if let r = locate(name) { out[name] = r }
    }
    return out
  }

  /// True if Xcode Command Line Tools appear installed.
  public func hasXcodeCLT() -> Bool {
    xcodeSelectBinDir() != nil
  }

  /// Invalidate a single cache entry (after a failed exec, say).
  public func invalidate(_ name: String) {
    cache.removeValue(forKey: name)
  }

  /// Invalidate all cached resolutions.
  public func invalidateAll() {
    cache.removeAll()
  }

  // MARK: - Private

  private nonisolated func xcodeSelectBinDir() -> URL? {
    let defaultCLT = URL(fileURLWithPath: "/Library/Developer/CommandLineTools/usr/bin")
    if FileManager.default.fileExists(atPath: defaultCLT.path) {
      return defaultCLT
    }
    let xcodeCLT = URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer/usr/bin")
    if FileManager.default.fileExists(atPath: xcodeCLT.path) {
      return xcodeCLT
    }
    return nil
  }
}
