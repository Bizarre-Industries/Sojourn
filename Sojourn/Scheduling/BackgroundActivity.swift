import Foundation

/// Wraps NSBackgroundActivityScheduler. Schedules the daily outdated-packages
/// refresh. Activity id app.bizarre.sojourn.refresh-outdated.
/// See docs/ARCHITECTURE.md section 7 (Scheduling mechanism) and section 11.
actor BackgroundActivity {
  static let refreshActivityID = "app.bizarre.sojourn.refresh-outdated"

  init() {}
}
