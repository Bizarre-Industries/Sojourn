import Foundation
import Testing
@testable import Sojourn

struct ToolLocatorTests {
  @Test func locatesGitOnSystem() async {
    // /usr/bin/git ships with Xcode Command Line Tools on every dev Mac
    // and via `xcode-select -p` fallback path.
    let locator = ToolLocator()
    let git = await locator.locate("git")
    #expect(git != nil)
  }

  @Test func missingBinaryReturnsNil() async {
    let locator = ToolLocator()
    let bogus = await locator.locate("sojourn-definitely-not-a-real-tool")
    #expect(bogus == nil)
  }

  @Test func resultIsCached() async {
    let locator = ToolLocator()
    _ = await locator.locate("git")
    let snap = await locator.snapshot()
    #expect(snap.contains(where: { $0.tool == "git" }))
  }

  @Test func seedPopulatesCache() async {
    let locator = ToolLocator()
    let fake = ToolResolution(
      tool: "mpm",
      url: URL(fileURLWithPath: "/opt/homebrew/bin/mpm"),
      source: .cached
    )
    await locator.seed([fake])
    let got = await locator.locate("mpm")
    #expect(got?.url.path == "/opt/homebrew/bin/mpm")
    #expect(got?.source == .cached)
  }

  @Test func locateAllFiltersMisses() async {
    let locator = ToolLocator()
    let got = await locator.locateAll(["git", "sojourn-absolutely-missing"])
    #expect(got["git"] != nil)
    #expect(got["sojourn-absolutely-missing"] == nil)
  }

  @Test func hasXcodeCLTDoesNotCrash() async {
    let locator = ToolLocator()
    // On a dev Mac running this test, CLT is almost always installed. We
    // accept both outcomes — the assertion is only that the probe is safe.
    _ = await locator.hasXcodeCLT()
  }

  @Test func invalidateRemovesCached() async {
    let locator = ToolLocator()
    _ = await locator.locate("git")
    await locator.invalidate("git")
    let snap = await locator.snapshot()
    #expect(!snap.contains(where: { $0.tool == "git" }))
  }
}
