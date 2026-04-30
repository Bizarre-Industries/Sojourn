// Sojourn — test fixture bundle resolver
//
// `Bundle.module` is synthesized by SwiftPM for resource-bearing targets.
// Xcode test bundles do not get it. Use `Bundle.sojournFixtures` in tests
// so the same source compiles under both `swift test` and
// `xcodebuild test`.
//
// Both build paths place fixtures under a `Fixtures/` subdirectory in the
// resulting bundle, so callers should pass `subdirectory: "Fixtures"`.

import Foundation

private final class _SojournTestsBundleAnchor {}

extension Bundle {
  static var sojournFixtures: Bundle {
    #if SWIFT_PACKAGE
    return .module
    #else
    return Bundle(for: _SojournTestsBundleAnchor.self)
    #endif
  }

  /// Resolve a fixture URL across both build paths. SPM places fixtures
  /// under `Fixtures/`, xcodebuild may place them at the bundle root or
  /// under `Fixtures/` depending on the project.yml `resources` shape
  /// and the active Xcode version's resource processing. Try every
  /// reasonable location.
  static func sojournFixtureURL(name: String, ext: String) -> URL? {
    let bundle = sojournFixtures
    let subdirs: [String?] = ["Fixtures", nil]
    for sub in subdirs {
      if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: sub) {
        return url
      }
    }
    // Last-ditch: walk the bundle's resourceURL for a directory named
    // Fixtures and look for the file inside.
    if let resources = bundle.resourceURL {
      let candidate = resources.appendingPathComponent("Fixtures/\(name).\(ext)")
      if FileManager.default.fileExists(atPath: candidate.path) {
        return candidate
      }
    }
    return nil
  }
}
