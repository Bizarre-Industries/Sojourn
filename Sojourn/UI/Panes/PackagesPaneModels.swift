// Sojourn — Packages pane models

import Foundation

internal struct PackageManagerSummary: Identifiable, Hashable {
  internal let id: String
  internal let name: String
  internal let symbol: String
  internal let count: Int
  internal let tierLabel: String
  internal let cooldownWindow: String
  internal let promptLabel: String
  internal let source: String
  internal let description: String

  internal init(
    id: String,
    name: String,
    symbol: String,
    count: Int,
    tierLabel: String,
    cooldownWindow: String,
    promptLabel: String,
    source: String,
    description: String
  ) {
    self.id = id
    self.name = name
    self.symbol = symbol
    self.count = count
    self.tierLabel = tierLabel
    self.cooldownWindow = cooldownWindow
    self.promptLabel = promptLabel
    self.source = source
    self.description = description
  }

  internal init(
    id: String,
    name: String,
    symbol: String,
    count: Int,
    tier: BrewfileTier,
    promptLabel: String,
    source: String,
    description: String
  ) {
    self.init(
      id: id,
      name: name,
      symbol: symbol,
      count: count,
      tierLabel: tier.rawValue.uppercased(),
      cooldownWindow: Self.cooldownWindow(for: tier),
      promptLabel: promptLabel,
      source: source,
      description: description
    )
  }

  private static func cooldownWindow(for tier: BrewfileTier) -> String {
    let days = tier.defaultCooldownDays
    return days == 1 ? "1 day" : "\(days) days"
  }
}

internal struct MasHelperActionError: Identifiable {
  internal let id = UUID()
  internal let title: String
  internal let message: String

  internal static func register(_ error: any Error) -> MasHelperActionError {
    MasHelperActionError(
      title: "Could not register helper",
      message: "System Settings may still need to approve Sojourn in General > Login Items. Cause: \(String(describing: error))"
    )
  }

  internal static func revoke(_ error: any Error) -> MasHelperActionError {
    MasHelperActionError(
      title: "Could not revoke helper",
      message: "Check that Sojourn is allowed to manage its helper, then retry. Cause: \(String(describing: error))"
    )
  }
}
