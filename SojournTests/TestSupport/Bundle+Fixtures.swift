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
}
