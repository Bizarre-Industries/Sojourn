import XCTest

/// UI smoke tests. Runs against the built Sojourn.app from the Xcode project.
/// `@MainActor` because XCUIApplication APIs are MainActor-isolated under
/// Swift 6 strict concurrency.
@MainActor
final class SojournUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testAppLaunches() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
  }

  /// Click each sidebar entry. Assert the corresponding pane's
  /// accessibilityIdentifier becomes hittable. Identifiers are wired in
  /// Sojourn/UI/Panes.swift + Sojourn/UI/Panes/Power/PowerSurfaces.swift.
  func testSidebarNavigation() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

    // v0.2 sidebar: 10 typed Pane enum cases per
    // docs/process/plans/v0.2-plan.md step 3. Pane IDs match the
    // accessibilityIdentifier wired in MainWindowView (sidebar.<rawValue>)
    // and the existing pane-side identifier convention. The .dashboard
    // case maps to OverviewPane (rawValue "dashboard"), which still
    // exposes its v0.1 "pane.overview" identifier until the v0.2
    // step 4 Panes.swift split rewires it.
    let entries: [(String, String)] = [
      ("sidebar.dashboard",     "pane.overview"),
      ("sidebar.packages",      "pane.packages"),
      ("sidebar.generations",   "pane.generations"),
      ("sidebar.macosFeatures", "pane.macosFeatures"),
      ("sidebar.preferences",   "pane.preferences"),
      ("sidebar.sync",          "pane.sync"),
      ("sidebar.machines",      "pane.machines"),
      ("sidebar.advisories",    "pane.advisories"),
      ("sidebar.jobs",          "pane.jobs"),
      ("sidebar.settings",      "pane.settings")
    ]

    for (sidebarID, paneID) in entries {
      let row = app.buttons[sidebarID]
      if !row.waitForExistence(timeout: 4) {
        XCTFail("Sidebar entry \(sidebarID) not found")
        continue
      }
      row.click()
      let pane = app.scrollViews[paneID]
      let other = app.otherElements[paneID]
      let visible = pane.waitForExistence(timeout: 4) || other.waitForExistence(timeout: 1)
      XCTAssertTrue(visible, "Pane \(paneID) did not surface after clicking \(sidebarID)")
    }
  }
}
