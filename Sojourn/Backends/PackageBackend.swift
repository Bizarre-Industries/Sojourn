// Sojourn — PackageBackend protocol.
//
// Audit §3.2.1. Promotes ADR-0010 to Accepted: every package-manager
// service (`MPMService`, future `BrewService`/`CaskService`/`MasService`,
// runtime plugins) conforms to this single protocol. `JobRunner` and
// `SyncCoordinator` work against the protocol — not against concrete
// actors — so swapping mpm for native brew or wiring a plugin requires
// zero changes at the call site.

import Foundation

/// A backend that lists, installs, and removes packages from one ecosystem.
internal protocol PackageBackend: Sendable {
  /// Stable identifier for the manager — `"brew"`, `"npm"`, `"cargo"`, etc.
  /// Matches the `manager` keys in `mpm` JSON output.
  var managerID: String { get }

  /// All currently-installed packages, keyed by stable id.
  func installed() async throws -> ManagerSnapshot

  /// Packages with a newer version than installed.
  func outdated() async throws -> [ManagedPackage]

  /// Install one or more packages. Returns the resulting installed set.
  func install(_ packages: [String]) async throws -> [ManagedPackage]

  /// Remove one or more packages.
  func remove(_ packages: [String]) async throws

  /// Upgrade one or more packages (or all if empty).
  func upgrade(_ packages: [String]) async throws

  /// Free-text search against the manager's own index.
  func search(_ query: String) async throws -> [ManagedPackage]
}

internal enum BackendError: Error, Sendable {
  case unknownManager(String)
  case backendNotConfigured(String)
  case operationUnsupported(String, String)
}
