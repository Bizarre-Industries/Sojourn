// Sojourn — InstallSource
//
// Persisted first-launch install-source classification for ADR-0020.
// Cask installs are updated by Homebrew; direct DMG and unknown installs
// keep Sparkle enabled so direct-download users do not silently rot.

import Foundation

internal enum InstallSource: String, Sendable, Codable, Equatable {
  case cask
  case dmg
  case unknown

  internal var allowsSparkleUpdates: Bool {
    switch self {
    case .cask:
      false
    case .dmg, .unknown:
      true
    }
  }

  internal var label: String {
    switch self {
    case .cask:
      String(localized: "Homebrew cask")
    case .dmg:
      String(localized: "Direct DMG")
    case .unknown:
      String(localized: "Unknown install")
    }
  }
}
