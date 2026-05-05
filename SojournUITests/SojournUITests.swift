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
    launchAgentApp(app)
    XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(pane(app, "pane.overview").waitForExistence(timeout: 10))
    XCTAssertTrue(toolbarButton(app, "toolbar.refresh").waitForExistence(timeout: 4))
    XCTAssertTrue(toolbarButton(app, "toolbar.pull").exists)
    XCTAssertTrue(toolbarButton(app, "toolbar.push").exists)
  }

  /// Click each sidebar entry. Assert the corresponding pane's
  /// accessibilityIdentifier loads in the split-view detail.
  func testSidebarNavigation() throws {
    let app = XCUIApplication()
    launchAgentApp(app)
    XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

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
      let row = sidebarEntry(app, sidebarID)
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
      XCTAssertNotNil(
        visiblePane,
        "Pane \(paneID) did not load after clicking \(sidebarID)"
      )
    }
  }

  func testPackagesPaneShowsStage2InventorySurface() throws {
    let app = XCUIApplication()
    launchAgentApp(app)
    XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

    let row = sidebarEntry(app, "sidebar.packages")
    XCTAssertTrue(row.waitForExistence(timeout: 4))
    row.click()

    XCTAssertTrue(pane(app, "pane.packages").waitForExistence(timeout: 4))
    XCTAssertTrue(app.otherElements["packages.inventory"].waitForExistence(timeout: 4))
    XCTAssertFalse(app.staticTexts["Outdated scan unavailable"].exists)
  }

  func testToolbarLabelsAndPaneActionsExposeAccessibility() throws {
    let app = XCUIApplication()
    launchAgentApp(app)
    XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

    XCTAssertEqual(toolbarButton(app, "toolbar.refresh").label, "Refresh")
    XCTAssertEqual(toolbarButton(app, "toolbar.pull").label, "Pull and Apply")
    XCTAssertEqual(toolbarButton(app, "toolbar.push").label, "Push After Scan")
    XCTAssertFalse(toolbarButton(app, "toolbar.status").label.isEmpty)

    let paneActions: [(sidebarID: String, actionID: String, label: String)] = [
      ("sidebar.packages", "packages.refresh", "Refresh package inventory"),
      ("sidebar.containers", "containers.rescan", "Rescan container runtimes"),
      ("sidebar.generations", "generations.refresh", "Refresh generations"),
      ("sidebar.macosFeatures", "macosFeatures.refresh", "Refresh macOS feature state"),
      ("sidebar.advisories", "advisories.refresh", "Refresh advisory cache")
    ]

    for (sidebarID, actionID, label) in paneActions {
      let row = sidebarEntry(app, sidebarID)
      XCTAssertTrue(row.waitForExistence(timeout: 4), "Missing \(sidebarID)")
      row.click()
      let action = toolbarButton(app, actionID)
      XCTAssertTrue(action.waitForExistence(timeout: 4), "Missing \(actionID)")
      XCTAssertEqual(action.label, label, "Unexpected label for \(actionID)")
    }
  }

  private func launchAgentApp(_ app: XCUIApplication) {
    app.launch()

    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline {
      switch app.state {
      case .runningForeground, .runningBackground:
        return
      case .unknown, .notRunning:
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
      @unknown default:
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
      }
    }

    XCTFail("Sojourn did not launch; final state: \(app.state.rawValue)")
  }

  private func pane(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    let scrollView = app.scrollViews[identifier]
    if scrollView.exists { return scrollView }
    return app.otherElements[identifier]
  }

  private func sidebarEntry(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    let label = app.staticTexts[identifier]
    if label.exists { return label }
    return app.buttons[identifier]
  }

  private func toolbarButton(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    let button = app.buttons[identifier]
    if button.exists { return button }
    let staticText = app.staticTexts[identifier]
    if staticText.exists { return staticText }
    return app.otherElements[identifier]
  }
}
