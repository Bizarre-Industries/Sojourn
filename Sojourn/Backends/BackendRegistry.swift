// Sojourn — BackendRegistry actor.
//
// Audit §3.2.5. The registry is the single dispatcher: every place that
// needs to install / list / outdated for a `ManagerID` calls
// `registry.package(for: id)?.installed()` instead of touching
// `MPMService` directly. Native backends register themselves; the
// plugin host (Stage 14) registers each loaded plugin.
//
// Concurrency: actor isolation serializes registration + lookup, so a
// UI thread reading while bootstrap registers a plugin is safe.

import Foundation

internal actor BackendRegistry {
  private var packageBackends: [String: any PackageBackend] = [:]
  private var dotfileBackend: (any DotfileBackend)?
  private var prefBackend: (any PrefBackend)?
  private var secretBrokers: [String: any SecretBroker] = [:]

  internal init() {}

  // MARK: - Package backends

  internal func register(_ backend: any PackageBackend) {
    packageBackends[backend.managerID] = backend
  }

  internal func package(for managerID: String) -> (any PackageBackend)? {
    packageBackends[managerID]
  }

  internal var allManagerIDs: [String] {
    Array(packageBackends.keys).sorted()
  }

  /// Aggregate `installed()` across every registered package backend.
  /// Errors from individual backends are swallowed so one missing tool
  /// doesn't black-hole the whole sweep.
  internal func installedAcrossAll() async -> [String: ManagerSnapshot] {
    var out: [String: ManagerSnapshot] = [:]
    for (id, backend) in packageBackends {
      if let snap = try? await backend.installed() {
        out[id] = snap
      }
    }
    return out
  }

  // MARK: - Dotfile / pref

  internal func register(_ backend: any DotfileBackend) {
    dotfileBackend = backend
  }
  internal var dotfile: (any DotfileBackend)? { dotfileBackend }

  internal func register(_ backend: any PrefBackend) {
    prefBackend = backend
  }
  internal var pref: (any PrefBackend)? { prefBackend }

  // MARK: - Secret brokers

  internal func register(_ broker: any SecretBroker) {
    secretBrokers[broker.brokerID] = broker
  }

  internal func secretBroker(for id: String) -> (any SecretBroker)? {
    secretBrokers[id]
  }

  /// Detection-order ladder per ADR-0011: 1Password → Bitwarden →
  /// Keychain → age. Returns the first available broker.
  internal func firstAvailableSecretBroker() async -> (any SecretBroker)? {
    for id in ["op", "bw", "keychain", "age"] {
      if let broker = secretBrokers[id], await broker.isAvailable() {
        return broker
      }
    }
    return nil
  }
}
