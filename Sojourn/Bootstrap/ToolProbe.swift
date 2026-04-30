// Sojourn — ToolProbe actor.
//
// Audit §3.1.3. Lives under `Bootstrap/` so the bootstrap state machine
// can be split into probe / install / coordinate without dragging the
// whole `BootstrapService` into the call graph. Reusable for runtime
// "tool went missing" detection (audit §4.4.1).

import Foundation

internal actor ToolProbe {
  private let locator: ToolLocator

  internal init(locator: ToolLocator) {
    self.locator = locator
  }

  /// Probe every tool Sojourn needs. Returns inventory snapshot — the
  /// bootstrap coordinator + Diagnostics pane both consume it.
  internal func probe() async -> ToolProbeReport {
    let git      = await locator.locate("git")?.url
    let brew     = await locator.locate("brew")?.url
    let mpm      = await locator.locate("mpm")?.url
    let chezmoi  = await locator.locate("chezmoi")?.url
    let age      = await locator.locate("age")?.url
    let gitleaks = await locator.locate("gitleaks")?.url
    let xcodeCLT = await locator.hasXcodeCLT()

    return ToolProbeReport(
      git: git,
      brew: brew,
      mpm: mpm,
      chezmoi: chezmoi,
      age: age,
      gitleaks: gitleaks,
      hasXcodeCLT: xcodeCLT
    )
  }
}

internal struct ToolProbeReport: Sendable, Hashable {
  internal let git: URL?
  internal let brew: URL?
  internal let mpm: URL?
  internal let chezmoi: URL?
  internal let age: URL?
  internal let gitleaks: URL?
  internal let hasXcodeCLT: Bool

  internal var missing: [String] {
    var m: [String] = []
    if git == nil       { m.append("git") }
    if brew == nil      { m.append("brew") }
    if mpm == nil       { m.append("mpm") }
    if chezmoi == nil   { m.append("chezmoi") }
    if age == nil       { m.append("age") }
    if gitleaks == nil  { m.append("gitleaks") }
    return m
  }

  internal var isComplete: Bool {
    missing.isEmpty && hasXcodeCLT
  }
}
