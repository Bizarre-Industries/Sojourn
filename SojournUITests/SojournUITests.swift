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

    let entries: [(String, String)] = [
      ("sidebar.overview",          "pane.overview"),
      ("sidebar.packages",          "pane.packages"),
      ("sidebar.dotfiles",          "pane.dotfiles"),
      ("sidebar.preferences",       "pane.preferences"),
      ("sidebar.machines",          "pane.machines"),
      ("sidebar.history",           "pane.history"),
      ("sidebar.conflicts",         "pane.conflicts"),
      ("sidebar.onboard",           "pane.onboard"),
      ("sidebar.secrets",           "pane.secrets"),
      ("sidebar.cleanup",           "pane.cleanup"),
      ("sidebar.diagnostics",       "pane.diagnostics"),
      ("sidebar.settings",          "pane.settings"),
      ("sidebar.jobs",              "pane.jobs"),
      ("sidebar.schedule",          "pane.schedule"),
      ("sidebar.age",               "pane.age"),
      ("sidebar.chezmoi-templates", "pane.chezmoi-templates"),
      ("sidebar.gitleaks-rules",    "pane.gitleaks-rules"),
      ("sidebar.authorization",     "pane.authorization"),
      ("sidebar.manager-detail",    "pane.manager-detail"),
      ("sidebar.backups",           "pane.backups"),
      ("sidebar.defaults-discover", "pane.defaults-discover"),
      ("sidebar.repo-setup",        "pane.repo-setup")
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
