// Sojourn — BootstrapCoordinator actor.
//
// Audit §3.1.3. Re-implements the bootstrap state machine on top of
// `ToolProbe` + `ToolInstaller`. Stage 8 ships this alongside the
// existing `BootstrapService`; future stages may migrate `AppStore` to
// instantiate the coordinator instead of the legacy service.
//
// State machine per `docs/explain/bootstrap-state-machine.md`:
//   unknown → probing → reportingStatus → awaitingUserConsent →
//   installingCLT → installingBrew → installingMPM → installingChezmoi →
//   ready (or failed)

import Foundation

internal actor BootstrapCoordinator {
  private let probe: ToolProbe
  private let installer: ToolInstaller
  private(set) var state: BootstrapState = .unknown

  internal init(probe: ToolProbe, installer: ToolInstaller) {
    self.probe = probe
    self.installer = installer
  }

  /// Probe the system; transition into reportingStatus or ready.
  internal func runProbe() async {
    state = .probingSystem
    let report = await probe.probe()
    if report.isComplete {
      state = .ready
      return
    }
    let inv = BootstrapState.Inventory(
      tools: [
        "git": report.git,
        "brew": report.brew,
        "mpm": report.mpm,
        "chezmoi": report.chezmoi,
        "age": report.age,
        "gitleaks": report.gitleaks
      ],
      hasCLT: report.hasXcodeCLT
    )
    state = .reportingStatus(inv)
  }

  /// Move past consent; install missing pieces in order.
  internal func proceed() async {
    state = .installingBrew
    do {
      try await installer.installHomebrew()
      state = .installingMPM
      // Stage 12 wires native mpm install. Today this is a marker —
      // the legacy `BootstrapService` handles the actual brew + mpm +
      // chezmoi install path.
      state = .installingChezmoi
      state = .ready
    } catch {
      state = .failed("\(error)")
    }
  }

  internal func reset() async {
    state = .unknown
  }
}
