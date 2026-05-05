// Sojourn — SparkleService
//
// Wraps Sparkle 2.9's `SPUStandardUpdaterController`. Owned by `AppStore`
// and constructed off the @MainActor at app launch via `Task.detached`
// so the menubar appearance budget (200ms per v0.2 perf baseline) is
// not blocked by Sparkle's appcast prefetch (per ADR-0025 +
// council 2026-05-04 stage6 perf-skeptic condition).
//
// Per ADR-0025 council 2026-05-03 amendments:
//   - Appcast `URLSession` timeout pinned to 30s via
//     `feedURLSession(for:)` delegate hook (Foundation default 60s).
//   - Sparkle 2.9.1 falls back internally from delta download/apply
//     failure to the regular update item. Sojourn records only terminal
//     updater abort diagnostics.
//
// RELEASE SMOKE: before tagging, verify generated appcast enclosure URLs
// download successfully and run clean Tahoe direct-DMG + cask update
// smoke checks.

import Foundation
import Observation
#if !SWIFT_PACKAGE
import Sparkle
#endif

/// Public-facing surface used by the SwiftUI menubar item.
#if !SWIFT_PACKAGE
@Observable
@MainActor
internal final class SparkleService: NSObject, SPUUpdaterDelegate {
  /// Diagnostic status string updated by the delegate.
  internal private(set) var statusMessage: String = ""

  private var controller: SPUStandardUpdaterController?

  internal override init() {
    super.init()
  }

  /// Begin background update checks. Safe to call multiple times.
  internal func start() {
    do {
      try updaterController().updater.start()
      statusMessage = ""
    } catch {
      statusMessage =
        String(localized: "Update checker failed: \(error.localizedDescription).")
        + " "
        + Self.updateRecoveryMessage
    }
  }

  /// User-initiated check. Wired from the menubar "Check for Updates…"
  /// item.
  internal func checkForUpdates() {
    updaterController().checkForUpdates(nil)
  }

  /// Homebrew cask installs update through `brew upgrade --cask
  /// sojourn`; Sparkle stays quiet to avoid duplicate prompts.
  internal func suppressForCaskInstall() {
    statusMessage = String(
      localized: "Homebrew handles updates. Run brew upgrade --cask sojourn."
    )
  }

  /// Whether the menubar item should be enabled. Reflects Sparkle's
  /// own `canCheckForUpdates` so concurrent checks do not stack.
  internal var canCheckForUpdates: Bool {
    controller?.updater.canCheckForUpdates ?? false
  }

  private func updaterController() -> SPUStandardUpdaterController {
    if let controller {
      return controller
    }
    let controller = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: self,
      userDriverDelegate: nil
    )
    self.controller = controller
    return controller
  }

  private static var updateRecoveryMessage: String {
    String(localized: "Try Check for Updates again.")
      + " "
      + String(
        localized: "If it keeps failing, install the latest DMG from GitHub Releases."
      )
  }

  // MARK: - SPUUpdaterDelegate

  /// Pin appcast fetch timeout to 30s. Foundation default is 60s
  /// which is too lenient for menubar perception per ADR-0025
  /// amendment.
  nonisolated func feedURLSession(for updater: SPUUpdater) -> URLSession? {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 60
    return URLSession(configuration: config)
  }

  /// Surface terminal updater errors. Sparkle handles delta-to-regular
  /// update fallback internally before this delegate is called.
  nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
    Task { @MainActor [weak self] in
      self?.statusMessage =
        String(localized: "Update stopped: \(error.localizedDescription).")
        + " "
        + Self.updateRecoveryMessage
    }
  }

  /// Clear diagnostics after a successful cycle. Terminal errors are
  /// recorded by `didAbortWithError`.
  nonisolated func updater(
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: (any Error)?
  ) {
    if error == nil {
      Task { @MainActor [weak self] in
        self?.statusMessage = ""
      }
    }
  }
}
#else
@Observable
@MainActor
internal final class SparkleService {
  /// Sparkle is Xcode-app only. The SwiftPM library target still needs
  /// AppStore to compile for unit tests, so it gets a no-op service with
  /// the same API.
  internal private(set) var statusMessage: String = ""

  internal init() {}

  internal func start() {
    statusMessage = String(localized: "Updates unavailable in this build.")
  }

  internal func checkForUpdates() {
    statusMessage = String(localized: "Updates unavailable in this build.")
  }

  internal func suppressForCaskInstall() {
    statusMessage = String(localized: "Homebrew handles updates. Run brew upgrade --cask sojourn.")
  }

  internal var canCheckForUpdates: Bool { false }
}
#endif
