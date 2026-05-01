// ToolProbeTests — smoke coverage for the bootstrap probe actor.
// Audit §3.1.3. Verifies probe() runs without crashing and produces a
// well-formed report; per-tool resolution is system-dependent and not
// asserted here.

import Foundation
@testable import Sojourn
import Testing

@Suite("ToolProbe")
struct ToolProbeTests {
  @Test("probe returns a report with deterministic isComplete computation")
  func probeRuns() async {
    let locator = ToolLocator()
    let probe = ToolProbe(locator: locator)
    let report = await probe.probe()
    // isComplete is derived from the per-tool URLs; check it agrees with
    // the underlying state rather than asserting any particular system.
    let hasAllTools = report.git != nil
      && report.brew != nil
      && report.chezmoi != nil
      && report.age != nil
      && report.gitleaks != nil
    #expect(report.isComplete == (hasAllTools && report.hasXcodeCLT))
  }
}
