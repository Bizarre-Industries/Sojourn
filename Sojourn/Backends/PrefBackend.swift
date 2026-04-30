// Sojourn — PrefBackend protocol.
//
// Audit §3.2.3. PrefService conforms today (defaults + plutil). Alternate
// plist tooling can land via the same surface. The cfprefsd watcher
// arrives in Stage 13 as a sibling capability behind `startDiscover()`.

import Foundation

internal protocol PrefBackend: Sendable {
  /// All known per-app preference domains.
  func domains() async throws -> [PreferenceDomain]

  /// Export a domain to a plist file at `url`.
  func export(domain: String, to url: URL) async throws

  /// Import a domain from a plist file at `url`. Quits the target app first
  /// if running; relaunches after import.
  func importPlist(domain: String, from url: URL) async throws

  /// Probe whether the app's preference container is readable. Used as
  /// the FDA canary on first run.
  func canAccess(domain: String) async -> Bool

  /// Start a Discover session. cfprefsd watcher records every prefs
  /// write under the supplied domain prefix until `stopDiscover()`.
  /// Stage 13 wires the watcher; this seam exists today as a no-op.
  func startDiscover(domainPrefix: String) async throws

  /// End the Discover session and return all newly-observed domains.
  func stopDiscover() async -> [PreferenceDomain]
}
