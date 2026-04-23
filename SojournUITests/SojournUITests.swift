import XCTest

/// UI smoke tests. Runs against the built Sojourn.app from the Xcode project.
final class SojournUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testAppLaunches() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
  }
}
