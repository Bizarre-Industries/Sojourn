// Sojourn — AutoUpdateTier
//
// Per-ecosystem tier controlling whether an update is auto-applied, how
// long the cooldown is, and whether user confirmation is required. Mirrors
// the tier table in docs/SECURITY.md (Supply-chain cooldown) and
// docs/ARCHITECTURE.md §7.

import Foundation

internal enum AutoUpdateTier: String, Sendable, Codable, Hashable, CaseIterable {
  case a  // Apple reviews (mas).
  case b  // Static, curated (brew formulae, cargo).
  case c  // Casks, pinned pip/uv project deps.
  case d  // Global pip/pipx (user prompt).
  case e  // Global npm (user must approve each version).

  internal var cooldownDays: Int {
    switch self {
    case .a: return 0
    case .b: return 7
    case .c: return 7
    case .d: return 7
    case .e: return 14
    }
  }

  internal var requiresUserPrompt: Bool {
    switch self {
    case .a, .b: return false
    case .c, .d, .e: return true
    }
  }

  internal var canAutoSilent: Bool {
    switch self {
    case .a, .b: return true
    case .c, .d, .e: return false
    }
  }

  internal var humanLabel: String {
    switch self {
    case .a: return "A — Apple-reviewed"
    case .b: return "B — Curated"
    case .c: return "C — User-prompt"
    case .d: return "D — Global interpreter"
    case .e: return "E — Global npm"
    }
  }
}

internal enum ManagerTier {
  internal static let defaults: [String: AutoUpdateTier] = [
    "mas": .a,
    "brew": .b,
    "cargo": .b,
    "cask": .c,
    "pip": .d,
    "pipx": .d,
    "uvx": .d,
    "gem": .d,
    "composer": .d,
    "vscode": .c,
    "yarn": .d,
    "npm": .e,
  ]

  internal static func tier(for managerID: String) -> AutoUpdateTier {
    defaults[managerID] ?? .c
  }
}
