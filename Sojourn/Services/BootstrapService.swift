// Sojourn — BootstrapService
//
// State machine for first-run bootstrap per docs/BOOTSTRAP.md and
// docs/ARCHITECTURE.md §9:
//
//   .unknown
//     → .probingSystem          // parallel locate brew/git/mpm/chezmoi/age/gitleaks/CLT
//     → .reportingStatus        // show inventory
//     → .awaitingUserConsent    // single "Install missing" sheet
//     → .installingCLT          // xcode-select --install; poll
//     → .installingBrew         // signed .pkg via /usr/sbin/installer
//     → .installingMpm          // brew install meta-package-manager
//     → .installingChezmoi      // brew install chezmoi
//     → .ready
//     → .failed(Error)

import Foundation
import Observation

internal enum BootstrapState: Sendable, Equatable {
  case unknown
  case probingSystem
  case reportingStatus(Inventory)
  case awaitingUserConsent(Inventory)
  case installingCLT
  case installingBrew
  case installingMPM
  case installingChezmoi
  case ready
  case failed(String)

  internal struct Inventory: Sendable, Equatable, Hashable {
    internal let tools: [String: URL?]
    internal let hasCLT: Bool

    internal var missing: [String] {
      tools.filter { $0.value == nil }.keys.sorted()
    }
  }
}

@Observable
@MainActor
internal final class BootstrapService {
  internal private(set) var state: BootstrapState = .unknown

  private let locator: ToolLocator
  private let brew: BrewService
  private let subprocess: SubprocessRunner

  internal init(locator: ToolLocator, brew: BrewService, subprocess: SubprocessRunner) {
    self.locator = locator
    self.brew = brew
    self.subprocess = subprocess
  }

  internal static let probeTools = ["brew", "git", "mpm", "chezmoi", "age", "gitleaks"]

  internal func probe() async {
    state = .probingSystem
    let resolutions = await locator.locateAll(Self.probeTools)
    let hasCLT = await locator.hasXcodeCLT()
    var tools: [String: URL?] = [:]
    for name in Self.probeTools {
      tools[name] = resolutions[name]?.url
    }
    let inv = BootstrapState.Inventory(tools: tools, hasCLT: hasCLT)
    if inv.missing.isEmpty && inv.hasCLT {
      state = .ready
    } else {
      state = .reportingStatus(inv)
    }
  }

  internal func consent(inventory: BootstrapState.Inventory) {
    state = .awaitingUserConsent(inventory)
  }

  internal func proceed() async {
    guard case .awaitingUserConsent(let inv) = state else { return }

    if !inv.hasCLT {
      state = .installingCLT
      if await installCLT() == false {
        state = .failed("Xcode Command Line Tools install did not complete.")
        return
      }
    }

    if inv.missing.contains("brew") {
      state = .installingBrew
      do {
        let release = try await brew.resolveLatestRelease()
        let tmp = FileManager.default.temporaryDirectory
          .appendingPathComponent("Homebrew-\(release.tagName).pkg")
        try await brew.downloadPkg(release, to: tmp)
        try await brew.verifySignature(at: tmp)
        try await brew.install(pkg: tmp)
        _ = try await brew.postVerify()
      } catch {
        state = .failed("brew install failed: \(error)")
        return
      }
    }

    if inv.missing.contains("mpm") {
      state = .installingMPM
      if await brewInstall(formula: "meta-package-manager") == false {
        state = .failed("mpm install via brew failed.")
        return
      }
    }

    if inv.missing.contains("chezmoi") {
      state = .installingChezmoi
      if await brewInstall(formula: "chezmoi") == false {
        state = .failed("chezmoi install via brew failed.")
        return
      }
    }

    await locator.invalidateAll()
    await probe()
  }

  // MARK: - Private

  private func installCLT() async -> Bool {
    do {
      _ = try await subprocess.run(
        tool: URL(fileURLWithPath: "/usr/bin/xcode-select"),
        args: ["--install"],
        timeout: 5
      )
    } catch {
      // xcode-select --install exits non-zero if already installed or on
      // user cancel. Both are fine — we poll below.
    }
    let deadline = Date().addingTimeInterval(600)
    while Date() < deadline {
      if await locator.hasXcodeCLT() {
        return true
      }
      try? await Task.sleep(nanoseconds: 5_000_000_000)
    }
    return false
  }

  private func brewInstall(formula: String) async -> Bool {
    guard let brewURL = await locator.locate("brew")?.url else { return false }
    do {
      _ = try await subprocess.run(
        tool: brewURL,
        args: ["install", formula],
        timeout: 900
      )
      return true
    } catch {
      return false
    }
  }
}
