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
//   - Delta-apply failure fallback is delegate-callback-based, not
//     framework-automatic. SparkleService.updater(_:didAbortWithError:)
//     inspects `(error as NSError).code` for
//     `SUDeltaUpdateError = 4002`. On that code, the updater is
//     re-invoked with the full DMG enclosure and diagnostic status
//     "Update download restarting (delta unavailable)" is set.
//   - Council 2026-05-04 stage6 architect condition: fallback-loop
//     guard prevents recursing if the fallback also fails.
//
// CORRUPT-DELTA SMOKE TEST DEFERRED: ADR-0025 hard-requires a clean
// Tahoe VM smoke before tagging v0.3.0. Council 2026-05-04 stage6
// approved deferral to tag pre-flight per maintainer decision. Logged
// in `.Codex/council-logs/2026-05-04-stage6-sparkle-delta.md`.

import Foundation
#if !SWIFT_PACKAGE
import Sparkle
#endif

/// Public-facing surface used by the SwiftUI menubar item.
#if !SWIFT_PACKAGE
@MainActor
internal final class SparkleService: NSObject, SPUUpdaterDelegate {
  /// Diagnostic status string updated by the delegate.
  internal private(set) var statusMessage: String = ""

  /// True after a delta-failure fallback has been triggered in this
  /// process session. Prevents recursion if the full-DMG re-fetch
  /// also returns the same error code.
  /// `nonisolated(unsafe)` — only read/written from delegate Task
  /// hops which always re-enter @MainActor; the flag itself is a
  /// race-free Bool whose first-write wins.
  nonisolated(unsafe) private var hasFallenBackThisSession: Bool = false

  /// Sparkle's error code for "delta update could not be applied".
  /// Source: Sparkle 2.9 SUErrors.h `SUDeltaUpdateError = 4002`.
  /// Inlined so we don't need the Sparkle ObjC enum exported into
  /// Swift, which is gated on Sparkle build flavors. Domain checked
  /// alongside (council 2026-05-04 stage6 architect condition).
  nonisolated private static let deltaUpdateFailedCode: Int = 4002
  nonisolated private static let sparkleErrorDomain: String = "SUSparkleErrorDomain"

  // Two-phase init: NSObject base class requires `super.init()` before
  // `self` is usable as a delegate. We bootstrap with a temporary nil-
  // delegate controller (discarded) so `self.controller` has an
  // initial value, then swap to the real bound controller.
  // `controller` is `var` to enable that single re-seat in init only;
  // not mutated thereafter.
  private var controller: SPUStandardUpdaterController

  internal override init() {
    self.controller = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
    super.init()
    self.controller = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: self,
      userDriverDelegate: nil
    )
  }

  /// Begin background update checks. Safe to call multiple times.
  internal func start() {
    do {
      try controller.updater.start()
    } catch {
      statusMessage = "Sparkle start failed: \(error.localizedDescription)"
    }
  }

  /// User-initiated check. Wired from the menubar "Check for Updates…"
  /// item.
  internal func checkForUpdates() {
    controller.checkForUpdates(nil)
  }

  /// Whether the menubar item should be enabled. Reflects Sparkle's
  /// own `canCheckForUpdates` so concurrent checks do not stack.
  internal var canCheckForUpdates: Bool {
    controller.updater.canCheckForUpdates
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

  /// Fall back to full DMG when Sparkle's delta apply fails. Council
  /// 2026-05-03 amendment requires this to be delegate-callback-based,
  /// not framework-automatic. Council 2026-05-04 stage6 architect
  /// condition: only retry once; do not loop.
  nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
    let nsError = error as NSError
    let isDeltaFailure =
      nsError.code == Self.deltaUpdateFailedCode
      && nsError.domain == Self.sparkleErrorDomain
    guard isDeltaFailure else {
      Task { @MainActor [weak self] in
        self?.statusMessage = "Update aborted: \(error.localizedDescription)"
      }
      return
    }
    Task { @MainActor [weak self] in
      guard let self else { return }
      if self.hasFallenBackThisSession {
        self.statusMessage = "Update failed twice (delta + full). Try again later."
        return
      }
      self.hasFallenBackThisSession = true
      self.statusMessage = "Update download restarting (delta unavailable)"
      // Re-invoke the updater. Sparkle 2 will re-fetch the appcast and
      // pick the full DMG enclosure since the delta path is now poisoned
      // for this session.
      self.controller.checkForUpdates(nil)
    }
  }

  /// Record diagnostics for delta failures inside the cycle callback.
  /// Distinct from `didAbortWithError` which fires on terminal errors.
  nonisolated func updater(
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: (any Error)?
  ) {
    if let error,
       (error as NSError).code == Self.deltaUpdateFailedCode,
       (error as NSError).domain == Self.sparkleErrorDomain {
      Task { @MainActor [weak self] in
        self?.statusMessage = "Delta update failed; will retry full bundle on next check."
      }
    }
  }
}
#else
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

  internal var canCheckForUpdates: Bool { false }
}
#endif
