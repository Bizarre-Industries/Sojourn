// Sojourn — Generation model
//
// A "generation" is a frozen snapshot of declarative state at some point
// in time. Tarball under
// `~/Library/Application Support/Sojourn/generations/<N>.tar.zst` plus
// a matching git tag `sojourn-gen-<N>` in the chezmoi source repo.
//
// Per ADR-0018 + v0.2-plan §6 + perf-council condition (zstd-19,
// retention 30 snapshots).

import Foundation

internal struct Generation: Sendable, Hashable, Identifiable, Codable {
  /// Monotonically increasing integer. Display "Generation 7" matches
  /// `7.tar.zst` and the `sojourn-gen-7` git tag.
  internal let number: Int

  /// Local-machine creation timestamp (ISO 8601 in JSON).
  internal let createdAt: Date

  /// Optional commit SHA in the chezmoi source repo at the time of
  /// snapshot. Empty if the source isn't a git repo.
  internal let chezmoiCommit: String?

  /// Human-readable note attached at create time.
  internal let note: String

  /// Counts surfaced in the Generations list without unpacking.
  internal let brewfileCounts: BrewfileAST.Counts

  internal var id: Int { number }

  internal var tag: String { "sojourn-gen-\(number)" }
  internal var archiveFilename: String { "\(number).tar.zst" }
}

/// Manifest stored alongside the tarball as `<N>.json`. Lets the
/// GenerationsPane render the list without unpacking each archive.
internal struct GenerationManifest: Sendable, Hashable, Identifiable, Codable {
  internal var generation: Generation
  internal var archiveSizeBytes: Int64
  internal var sha256: String

  internal var id: Int { generation.number }
}
