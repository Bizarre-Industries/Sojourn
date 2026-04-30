// Sojourn — DotfileBackend protocol.
//
// Audit §3.2.2. ChezmoiService conforms today; alternates land later.
// Surface mirrors the chezmoi commands Sojourn invokes plus the audit
// §2.2 additions (externals, merge, unmanaged, forget, doctor, state).

import Foundation

internal protocol DotfileBackend: Sendable {
  /// All managed entries (files, dirs, scripts, symlinks).
  func managed() async throws -> [DotfileManagedEntry]

  /// Per-entry status (clean / modified / created / removed).
  func status() async throws -> [DotfileStatusEntry]

  /// Diff between source and target for a single path.
  func diff(_ path: String) async throws -> String

  /// Apply a single path (or all). Use `force: true` for binaries / plists.
  func apply(_ path: String?, force: Bool) async throws

  /// Three-way merge for text dotfiles (Stage 11).
  func merge(_ path: String) async throws

  /// Files in $HOME not managed by chezmoi (Stage 11).
  func unmanaged() async throws -> [String]

  /// Stop tracking a path without deleting it (Stage 11).
  func forget(_ path: String) async throws

  /// `chezmoi doctor` output for the diagnostics bundle (Stage 11).
  func doctor() async throws -> String

  /// Refresh externals (Stage 11).
  func update() async throws
}

internal struct DotfileManagedEntry: Sendable, Hashable, Codable, Identifiable {
  internal var id: String { name }
  internal let name: String
  internal let type: String           // "file" | "dir" | "script" | "symlink"
  internal let target: String?
  internal let isEncrypted: Bool
  internal let isTemplate: Bool
}

internal struct DotfileStatusEntry: Sendable, Hashable, Codable, Identifiable {
  internal var id: String { path }
  internal let path: String
  internal let sourceState: String    // " M" | " A" | " R" | "  " etc.
  internal let targetState: String
}
