import Foundation
import Testing
@testable import Sojourn

/// Fixture-backed tests for MPMService JSON decoding.
/// See docs/ARCHITECTURE.md section 5.1.
struct MPMServiceTests {
  @Test func decodeInstalledFixture() throws {
    let url = Bundle.sojournFixtureURL(name: "mpm-installed", ext: "json")
    #expect(url != nil, "missing fixture: Fixtures/mpm-installed.json")

    guard let url else { return }
    let data = try Data(contentsOf: url)
    let decoded = try JSONDecoder().decode([String: ManagerSnapshot].self, from: data)

    #expect(decoded["brew"] != nil)
    #expect((decoded["brew"]?.packages.count ?? 0) >= 1)
  }
}
