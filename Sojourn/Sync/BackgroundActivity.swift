// Sojourn — BackgroundActivity
//
// Wrap NSBackgroundActivityScheduler so Phase 4 can schedule a daily
// refresh of outdated-package advisories + OSV bypass checks. See
// docs/ARCHITECTURE.md §6.

import Foundation

internal final class BackgroundActivity: @unchecked Sendable {
  internal static let refreshOutdatedID = "app.bizarre.sojourn.refresh-outdated"

  private var scheduler: NSBackgroundActivityScheduler?
  private let identifier: String

  internal init(identifier: String = refreshOutdatedID) {
    self.identifier = identifier
  }

  internal func start(
    interval: TimeInterval = 3600,
    tolerance: TimeInterval = 900,
    body: @escaping @Sendable (_ done: @escaping @Sendable () -> Void) -> Void
  ) {
    let s = NSBackgroundActivityScheduler(identifier: identifier)
    s.interval = interval
    s.tolerance = tolerance
    s.repeats = true
    s.qualityOfService = .utility
    s.schedule { completion in
      body { completion(.finished) }
    }
    self.scheduler = s
  }

  internal func invalidate() {
    scheduler?.invalidate()
    scheduler = nil
  }
}
