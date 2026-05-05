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
      clickSidebarEntry(app, sidebarID)
      XCTAssertTrue(
        pane(app, paneID).waitForExistence(timeout: 4),
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
    clickSidebarEntry(app, "sidebar.packages")

    XCTAssertTrue(pane(app, "pane.packages").waitForExistence(timeout: 4))
    XCTAssertTrue(identifierElement(app, "packages.inventory").waitForExistence(timeout: 4))
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

    let paneActions: [PaneAction] = [
      PaneAction(
        sidebarID: "sidebar.packages",
        actionID: "packages.refresh",
        label: "Refresh package inventory"
      ),
      PaneAction(
        sidebarID: "sidebar.containers",
        actionID: "containers.rescan",
        label: "Rescan container runtimes"
      ),
      PaneAction(
        sidebarID: "sidebar.generations",
        actionID: "generations.refresh",
        label: "Refresh generations"
      ),
      PaneAction(
        sidebarID: "sidebar.macosFeatures",
        actionID: "macosFeatures.refresh",
        label: "Refresh macOS feature state"
      ),
      PaneAction(
        sidebarID: "sidebar.advisories",
        actionID: "advisories.refresh",
        label: "Refresh advisory cache"
      )
    ]

    for action in paneActions {
      clickSidebarEntry(app, action.sidebarID)
      let button = toolbarButton(app, action.actionID)
      XCTAssertTrue(button.waitForExistence(timeout: 4), "Missing \(action.actionID)")
      XCTAssertEqual(button.label, action.label, "Unexpected label for \(action.actionID)")
    }
  }

  private func launchAgentApp(_ app: XCUIApplication) {
    app.launch()
    app.activate()

    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline {
      switch app.state {
      case .runningForeground:
        return
      case .runningBackground:
        app.activate()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
      case .unknown, .notRunning:
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
      @unknown default:
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
      }
    }

    XCTFail("Sojourn did not launch; final state: \(app.state.rawValue)")
  }

  private func pane(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    identifierElement(app, identifier)
  }

  private func sidebarEntry(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    identifierElement(app, identifier)
  }

  private func clickSidebarEntry(
    _ app: XCUIApplication,
    _ identifier: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    app.activate()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    let row = sidebarEntry(app, identifier)
    XCTAssertTrue(row.waitForExistence(timeout: 4), "Missing \(identifier)", file: file, line: line)

    if row.isHittable {
      row.click()
      waitForSidebarDestinationIfNeeded(app, identifier)
      return
    }

    app.activate()
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    if row.isHittable {
      row.click()
    } else {
      row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }
    waitForSidebarDestinationIfNeeded(app, identifier)
  }

  private func toolbarButton(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    identifierElement(app, identifier)
  }

  private func waitForSidebarDestinationIfNeeded(_ app: XCUIApplication, _ identifier: String) {
    guard identifier == "sidebar.containers" else { return }
    let probedAt = identifierElement(app, "containers.probed-at")
    guard probedAt.waitForExistence(timeout: 4) else { return }

    let deadline = Date().addingTimeInterval(8)
    while Date() < deadline {
      if !probedAt.label.localizedCaseInsensitiveContains("never") {
        return
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
  }

  private func identifierElement(
    _ app: XCUIApplication,
    _ identifier: String
  ) -> XCUIElement {
    let candidates = [
      app.buttons.matching(identifier: identifier),
      app.staticTexts.matching(identifier: identifier),
      app.scrollViews.matching(identifier: identifier),
      app.groups.matching(identifier: identifier),
      app.otherElements.matching(identifier: identifier),
      app.descendants(matching: .any).matching(identifier: identifier)
    ]
    .flatMap(\.allElementsBoundByIndex)

    if let hittable = candidates.first(where: { $0.exists && $0.isHittable }) {
      return hittable
    }
    if let existing = candidates.first(where: { $0.exists }) {
      return existing
    }
    return app.descendants(matching: .any)[identifier]
  }
}

private struct PaneAction {
  let sidebarID: String
  let actionID: String
  let label: String
}
