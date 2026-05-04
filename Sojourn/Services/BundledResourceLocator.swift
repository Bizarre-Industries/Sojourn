// Sojourn — BundledResourceLocator

import Foundation

internal enum BundledResourceLocator {
  internal static func reproDriftTemplateURL(bundle: Bundle = .main) -> URL? {
    #if SWIFT_PACKAGE
    Bundle.module.url(
      forResource: "repro-drift",
      withExtension: "md",
      subdirectory: "data"
    )
    #else
    bundle.url(
      forResource: "repro-drift",
      withExtension: "md",
      subdirectory: "data"
    )
    #endif
  }

  internal static func preferenceDomainsURL(bundle: Bundle = .main) -> URL? {
    #if SWIFT_PACKAGE
    Bundle.module.url(forResource: "preference-domains", withExtension: "json")
    #else
    bundle.url(forResource: "preference-domains", withExtension: "json")
    #endif
  }
}
