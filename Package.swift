// swift-tools-version: 6.1
// Sojourn — SPM manifest.
//
// The primary build is the Xcode project (`Sojourn.xcodeproj`), which produces
// the notarized `.app`. This manifest exists for:
//   • `swift test` running unit tests in CI without Xcode.
//   • Future headless CLI utilities (e.g., `scripts/update-registry.py`
//     successors that might be written in Swift).
//   • IDE integrations that prefer SPM over Xcode projects.
//
// SwiftUI views in `Sojourn/UI/` will not link cleanly under pure SPM because
// SPM does not provide an AppKit app bundle context. The `Sojourn` target
// below is declared as a library; the app executable is built only via Xcode.
//
// Dependencies are pinned to minor versions per `docs/ARCHITECTURE.md` §11.

import PackageDescription

let package = Package(
  name: "Sojourn",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "Sojourn", targets: ["Sojourn"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/swiftlang/swift-subprocess.git",
      .upToNextMinor(from: "0.4.0")
    ),
    .package(
      url: "https://github.com/orchetect/MenuBarExtraAccess.git",
      .upToNextMinor(from: "1.3.0")
    )
  ],
  targets: [
    .target(
      name: "Sojourn",
      dependencies: [
        .product(name: "Subprocess", package: "swift-subprocess"),
        .product(name: "MenuBarExtraAccess", package: "MenuBarExtraAccess")
      ],
      path: "Sojourn",
      exclude: [
        "Info.plist",
        "Sojourn.entitlements",
        "Resources/bin",
        "Resources/Assets.xcassets",
        "Config",
        // SwiftUI app entry + view layer: built only by Xcode (.app bundle).
        // SPM library cannot link @main cleanly, and AppKit/SwiftUI requires
        // an app bundle context that SPM does not provide.
        "App",
        "UI"
      ],
      resources: [
        .process("Resources/data")
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny")
        // NOTE: `InternalImportsByDefault` disabled because it prevents the
        // `@Observable` macro from emitting public `Observation.Observable`
        // conformances on public types. Revisit post-Swift-6.2 stabilization.
      ]
    ),
    .testTarget(
      name: "SojournTests",
      dependencies: ["Sojourn"],
      path: "SojournTests",
      resources: [
        .copy("Fixtures")
      ]
    )
  ]
)
