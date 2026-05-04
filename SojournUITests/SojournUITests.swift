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
  /// accessibilityIdentifier becomes hittable.
  func testSidebarNavigation() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

    // v0.3 sidebar: 11 typed Pane enum cases. Pane IDs match the
    // accessibilityIdentifier wired in MainWindowView (sidebar.<rawValue>)
    // and the pane-side identifier convention.
    let entries: [(String, String)] = [
      ("sidebar.dashboard", "pane.overview"),
      ("sidebar.packages", "pane.packages"),
      ("sidebar.containers", "pane.containers"),
      ("sidebar.generations", "pane.generations"),
      ("sidebar.macosFeatures", "pane.macos-features"),
      ("sidebar.preferences", "pane.preferences"),
      ("sidebar.sync", "pane.sync"),
      ("sidebar.machines", "pane.machines"),
      ("sidebar.advisories", "pane.advisories"),
      ("sidebar.jobs", "pane.jobs"),
      ("sidebar.settings", "pane.settings")
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
      let visiblePane: XCUIElement?
      if pane.waitForExistence(timeout: 4) {
        visiblePane = pane
      } else if other.waitForExistence(timeout: 1) {
        visiblePane = other
      } else {
        visiblePane = nil
      }
      XCTAssertTrue(
        visiblePane?.isHittable == true,
        "Pane \(paneID) did not become hittable after clicking \(sidebarID)"
      )
    }
  }
}
