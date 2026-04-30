// Sojourn — advisory feed actor.
//
// Audit §7 + §2.1.1. Pulls OSV (api.osv.dev) and GitHub Security
// Advisories. Caches in-memory and on disk. A high-severity hit on
// any installed package bypasses the cooldown gate per
// `docs/reference/cooldown-policy.md`.
//
// Stage 6 ships the actor scaffolding; Stage 10 wires the live fetch
// into `SyncCoordinator.push` and exposes the data via the Advisories
// pane (Stage 13).

import Foundation

internal actor AdvisoryService {
  private var cache: [String: AdvisoryReference] = [:]   // keyed by id
  private var lastFetch: Date?
  private let staleAfter: TimeInterval = 24 * 60 * 60    // refresh daily
  private let session: URLSession
  private let cacheURL: URL?

  internal init(session: URLSession = .shared, cacheURL: URL? = nil) {
    self.session = session
    self.cacheURL = cacheURL
  }

  // MARK: - Lookup

  /// Return advisories matching any of the provided PURLs. Triggers a
  /// background refresh if the cache is stale.
  internal func advisories(for purls: [PURL]) async -> [AdvisoryReference] {
    if isStale {
      try? await refresh()
    }
    let names = Set(purls.map { $0.name })
    return cache.values.filter { adv in
      adv.affectedPackages.contains { names.contains($0.name) }
    }
  }

  internal var isStale: Bool {
    guard let last = lastFetch else { return true }
    return Date().timeIntervalSince(last) > staleAfter
  }

  // MARK: - Refresh

  /// Refresh the OSV feed. Stage 10 swaps the no-op for a real fetch.
  internal func refresh() async throws {
    // Stage 10 wires `https://api.osv.dev/v1/query` and ingests the JSON
    // into `[AdvisoryReference]`. Stage 6 leaves the actor wired but
    // makes no network calls.
    lastFetch = Date()
  }

  /// Hydrate from on-disk cache (if a cacheURL was provided at init).
  internal func loadFromDisk() async {
    guard let cacheURL,
          let data = try? Data(contentsOf: cacheURL) else { return }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    if let snapshot = try? decoder.decode(CacheSnapshot.self, from: data) {
      self.cache = Dictionary(uniqueKeysWithValues: snapshot.advisories.map { ($0.id, $0) })
      self.lastFetch = snapshot.lastFetch
    }
  }

  internal func persistToDisk() async {
    guard let cacheURL else { return }
    let snapshot = CacheSnapshot(
      advisories: Array(cache.values),
      lastFetch: lastFetch ?? Date()
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(snapshot) {
      try? data.write(to: cacheURL, options: .atomic)
    }
  }

  // MARK: - Test seam

  internal func seed(_ advisories: [AdvisoryReference]) {
    for adv in advisories { cache[adv.id] = adv }
    lastFetch = Date()
  }
}

private struct CacheSnapshot: Codable {
  let advisories: [AdvisoryReference]
  let lastFetch: Date
}
