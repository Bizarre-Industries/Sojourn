// Sojourn — security advisory reference.
//
// Sojourn cross-references installed packages against OSV (api.osv.dev)
// and GitHub Security Advisories. A hit on a package the user has
// installed bypasses the cooldown gate per
// `docs/reference/cooldown-policy.md`.
//
// Audit §2.1.1 + §7. Stage 6 introduces the type; Stage 7 (Policy module)
// wires `AdvisoryService` to fetch and cache.

import Foundation

internal enum AdvisoryFeed: String, Sendable, Codable {
  case osv
  case ghsa
}

internal enum AdvisorySeverity: String, Sendable, Codable, Comparable {
  case low, moderate, high, critical

  internal static func < (lhs: AdvisorySeverity, rhs: AdvisorySeverity) -> Bool {
    let order: [AdvisorySeverity] = [.low, .moderate, .high, .critical]
    return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
  }
}

internal struct AdvisoryReference: Hashable, Sendable, Codable, Identifiable {
  internal let id: String                  // e.g. "GHSA-xxxx-xxxx-xxxx"
  internal let feed: AdvisoryFeed
  internal let severity: AdvisorySeverity
  internal let summary: String
  internal let publishedAt: Date
  internal let modifiedAt: Date
  internal let affectedPackages: [PURL]
  internal let fixedVersions: [String]
  internal let referenceURL: URL?

  internal init(
    id: String,
    feed: AdvisoryFeed,
    severity: AdvisorySeverity,
    summary: String,
    publishedAt: Date,
    modifiedAt: Date,
    affectedPackages: [PURL] = [],
    fixedVersions: [String] = [],
    referenceURL: URL? = nil
  ) {
    self.id = id
    self.feed = feed
    self.severity = severity
    self.summary = summary
    self.publishedAt = publishedAt
    self.modifiedAt = modifiedAt
    self.affectedPackages = affectedPackages
    self.fixedVersions = fixedVersions
    self.referenceURL = referenceURL
  }

  /// Whether the advisory is severe enough to bypass cooldown automatically.
  internal var triggersBypass: Bool {
    severity >= .high
  }
}
