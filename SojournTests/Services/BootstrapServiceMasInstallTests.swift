// Sojourn — BootstrapServiceMasInstallTests
//
// Verifies the v0.3 stage 7 addition of `BootstrapState.installingMas`:
//   - probeTools includes "mas"
//   - BootstrapState round-trips through Equatable / pattern-matching
//
// Live `proceed()` path is exercised via the existing BootstrapView
// snapshot smoke; this suite covers the additive enum case + probe
// list shape so a future maintainer cannot silently drop "mas" from
// probeTools without breaking a test.

import Testing
@testable import Sojourn

struct BootstrapServiceMasInstallTests {
  @Test
  func probeToolsIncludesMas() {
    #expect(BootstrapService.probeTools.contains("mas"))
  }

  @Test
  func probeToolsLengthBumpedToSix() {
    // brew, git, chezmoi, age, gitleaks, mas → 6 tools.
    #expect(BootstrapService.probeTools.count == 6)
  }

  @Test
  func installingMasStateExists() {
    let s: BootstrapState = .installingMas
    if case .installingMas = s {
      // ok
    } else {
      Issue.record("expected .installingMas to pattern-match")
    }
  }

  @Test
  func installingMasStateIsDistinct() {
    #expect(BootstrapState.installingMas != .installingChezmoi)
    #expect(BootstrapState.installingMas != .ready)
  }

  @Test
  func reproDriftTemplateBundled() {
    // OnboardPane.copyTemplate(into:) loads via subdirectory: "data".
    // Pinning the lookup contract here so a future bundle reorg cannot
    // silently break the "Copy repro-drift template" button.
    let url = Bundle.main.url(
      forResource: "repro-drift",
      withExtension: "md",
      subdirectory: "data"
    )
    #expect(url != nil, "repro-drift.md must ship under Resources/data")
  }
}
