// Sojourn — MPMPackageBackend.
//
// Audit §3.2.1 + ADR-0010. One adapter per `mpm`-covered manager id
// (brew, cask, mas, pip, pipx, npm, cargo, gem, composer, yarn,
// vscode, uvx). Each adapter forwards every `PackageBackend` call to
// the shared `MPMService` actor and filters by `managerID`.
//
// v0.1.0: wired into `BackendRegistry` from `AppStore.live()` so v0.2
// callers (SyncCoordinator + JobRunner) can switch to the protocol
// without touching the concrete `MPMService` callsites already shipped.

import Foundation

internal struct MPMPackageBackend: PackageBackend {
  internal let managerID: String
  private let mpm: MPMService

  internal init(managerID: String, mpm: MPMService) {
    self.managerID = managerID
    self.mpm = mpm
  }

  /// All managers `mpm` covers. Source of truth for the per-manager
  /// adapter fan-out at `AppStore.live()`.
  internal static let knownManagerIDs: [String] = [
    "brew", "cask", "mas",
    "pip", "pipx", "uvx",
    "npm", "yarn",
    "cargo", "gem", "composer",
    "vscode"
  ]

  internal func installed() async throws -> ManagerSnapshot {
    let all = try await mpm.installed()
    return all[managerID] ?? ManagerSnapshot(id: managerID, name: managerID)
  }

  internal func outdated() async throws -> [ManagedPackage] {
    let all = try await mpm.outdated()
    return all[managerID]?.packages ?? []
  }

  internal func install(_ packages: [String]) async throws -> [ManagedPackage] {
    try await mpm.install(manager: managerID, pkgs: packages)
    let snap = try await installed()
    let requested = Set(packages)
    return snap.packages.filter { requested.contains($0.id) }
  }

  internal func remove(_ packages: [String]) async throws {
    try await mpm.remove(manager: managerID, pkgs: packages)
  }

  internal func upgrade(_ packages: [String]) async throws {
    try await mpm.upgrade(manager: managerID, pkgs: packages)
  }

  internal func search(_ query: String) async throws -> [ManagedPackage] {
    // mpm wrapper doesn't surface `search` yet — phase 12 wires it.
    throw BackendError.operationUnsupported(managerID, "search")
  }
}
