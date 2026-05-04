// Sojourn — InstallSourceDetector
//
// ADR-0020 first-launch install-source detection. This intentionally
// probes known Homebrew prefixes instead of shelling out; app launches
// inherit a LaunchServices-minimal PATH, and ToolLocator owns subprocess
// discovery elsewhere.

import Foundation

internal enum InstallSourceDetector {
  internal static func detect(
    bundleURL: URL = Bundle.main.bundleURL,
    bundleVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    caskroomRoots: [URL]? = nil,
    fileManager: FileManager = .default
  ) -> InstallSource {
    if hasCaskReceipt(
      bundleVersion: bundleVersion,
      caskroomRoots: caskroomRoots ?? self.caskroomRoots(environment: environment),
      fileManager: fileManager
    ) {
      return .cask
    }

    if bundleURL.standardizedFileURL.path == "/Applications/Sojourn.app" {
      return .dmg
    }

    return .unknown
  }

  private static func caskroomRoots(environment: [String: String]) -> [URL] {
    var roots: [URL] = []
    if let prefix = environment["HOMEBREW_PREFIX"], !prefix.isEmpty {
      roots.append(URL(fileURLWithPath: prefix).appendingPathComponent("Caskroom", isDirectory: true))
    }
    roots.append(URL(fileURLWithPath: "/opt/homebrew/Caskroom", isDirectory: true))
    roots.append(URL(fileURLWithPath: "/usr/local/Caskroom", isDirectory: true))

    var seen: Set<String> = []
    return roots.filter { seen.insert($0.standardizedFileURL.path).inserted }
  }

  private static func hasCaskReceipt(
    bundleVersion: String?,
    caskroomRoots: [URL],
    fileManager: FileManager
  ) -> Bool {
    guard let bundleVersion, !bundleVersion.isEmpty, !bundleVersion.hasPrefix("$") else {
      return false
    }

    for root in caskroomRoots {
      let tokenDir = root.appendingPathComponent("sojourn", isDirectory: true)
      guard fileManager.fileExists(atPath: tokenDir.path) else { continue }

      let versionDir = tokenDir.appendingPathComponent(bundleVersion, isDirectory: true)
      if fileManager.fileExists(atPath: versionDir.path) {
        return true
      }
    }
    return false
  }
}
