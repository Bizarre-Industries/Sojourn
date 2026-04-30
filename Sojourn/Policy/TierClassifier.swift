// Sojourn — pure tier classifier.
//
// Audit §3.1.2. Surfaces tier classification under `Policy/` for the
// protocol-layer naming convention. The default table lives in
// `Models/AutoUpdateTier.swift` (`ManagerTier.defaults`). This module
// is a thin wrapper adding:
//
//   • per-package overrides
//   • lifecycle-script lift (any package with install hooks → tier E)

import Foundation

internal enum TierClassifier {
  internal static func classify(
    manager: String,
    package: String? = nil,
    lifecycleScripted: Bool = false,
    perPackageOverrides: [String: AutoUpdateTier] = [:]
  ) -> AutoUpdateTier {
    if let pkg = package, let override = perPackageOverrides[pkg] {
      return override
    }
    if lifecycleScripted {
      return .e
    }
    return ManagerTier.tier(for: manager)
  }

  internal static func autoSilent(_ tier: AutoUpdateTier) -> Bool {
    tier.canAutoSilent
  }
}
