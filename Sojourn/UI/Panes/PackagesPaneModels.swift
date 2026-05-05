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

  internal static func summaries(for counts: BrewfileAST.Counts) -> [PackageManagerSummary] {
    appSummaries(for: counts)
      + toolSummaries(for: counts)
      + editorSummaries(for: counts)
      + [tapSummary(for: counts)]
  }

  private static func appSummaries(for counts: BrewfileAST.Counts) -> [PackageManagerSummary] {
    [
      .init(
        id: "mas",
        name: "Mac App Store",
        symbol: "apple.logo",
        count: counts.mas,
        tier: .a,
        promptLabel: "Not required",
        source: "mas",
        description: "Reviewed App Store applications installed through mas."
      ),
      .init(
        id: "brew",
        name: "Homebrew",
        symbol: "terminal",
        count: counts.brews,
        tierLabel: "B-C",
        cooldownWindow: "7-14 days",
        promptLabel: "Depends on tap",
        source: "brew",
        description: "Homebrew formulae from the Brewfile. Third-party taps use the stricter tier."
      ),
      .init(
        id: "cargo",
        name: "Cargo",
        symbol: "shippingbox",
        count: counts.cargo,
        tier: .e,
        promptLabel: "Required before apply",
        source: "cargo",
        description: "Rust packages installed by cargo."
      )
    ]
  }

  private static func toolSummaries(for counts: BrewfileAST.Counts) -> [PackageManagerSummary] {
    [
      .init(
        id: "cask",
        name: "Casks",
        symbol: "app.dashed",
        count: counts.casks,
        tierLabel: "C-D",
        cooldownWindow: "14-21 days",
        promptLabel: "Depends on tap",
        source: "brew cask",
        description: "GUI apps and packaged installers."
      ),
      .init(
        id: "uv",
        name: "uv / Python",
        symbol: "chevron.left.forwardslash.chevron.right",
        count: counts.uv,
        tier: .e,
        promptLabel: "Required before apply",
        source: "uv",
        description: "Python tools managed through uv."
      ),
      .init(
        id: "npm",
        name: "npm global",
        symbol: "curlybraces",
        count: counts.npm,
        tier: .e,
        promptLabel: "Required before apply",
        source: "npm",
        description: "Global npm packages with lifecycle-script risk."
      )
    ]
  }

  private static func editorSummaries(for counts: BrewfileAST.Counts) -> [PackageManagerSummary] {
    [
      .init(
        id: "go",
        name: "Go install",
        symbol: "g.circle",
        count: counts.go,
        tier: .e,
        promptLabel: "Required before apply",
        source: "go",
        description: "Go module binaries."
      ),
      .init(
        id: "vscode",
        name: "VS Code",
        symbol: "curlybraces.square",
        count: counts.vscode,
        tier: .d,
        promptLabel: "Required before apply",
        source: "code",
        description: "VS Code extensions."
      ),
      .init(
        id: "krew",
        name: "krew",
        symbol: "k.square",
        count: counts.krew,
        tier: .e,
        promptLabel: "Required before apply",
        source: "kubectl krew",
        description: "kubectl plugin manager entries."
      )
    ]
  }

  private static func tapSummary(for counts: BrewfileAST.Counts) -> PackageManagerSummary {
    .init(
      id: "tap",
      name: "Homebrew taps",
      symbol: "point.3.connected.trianglepath.dotted",
      count: counts.taps,
      tierLabel: "Reference",
      cooldownWindow: "No package cooldown",
      promptLabel: "Not applicable",
      source: "brew tap",
      description: "Additional Homebrew repositories."
    )
  }
}

internal struct MasHelperActionError: Identifiable {
  internal let id = UUID()
  internal let title: String
  internal let message: String

  internal static func register(_ error: any Error) -> MasHelperActionError {
    MasHelperActionError(
      title: "Could not register helper",
      message:
        "System Settings may still need to approve Sojourn in General > Login Items. Cause: \(String(describing: error))"
    )
  }

  internal static func revoke(_ error: any Error) -> MasHelperActionError {
    MasHelperActionError(
      title: "Could not revoke helper",
      message:
        "Check that Sojourn is allowed to manage its helper, then retry. Cause: \(String(describing: error))"
    )
  }
}
