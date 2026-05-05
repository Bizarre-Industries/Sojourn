// Sojourn — package inventory row model

import Foundation

internal struct PackageInventoryRow: Identifiable, Hashable, Sendable {
  internal let id: String
  internal let managerID: String
  internal let kindLabel: String
  internal let packageID: String
  internal let detail: String
  internal let tierLabel: String
  internal let cooldownWindow: String
  internal let promptLabel: String
  internal let source: String
  internal let symbol: String

  internal static func rows(
    from ast: BrewfileAST?,
    managerID: String? = nil
  ) -> [PackageInventoryRow] {
    guard let ast else { return [] }
    let rows = ast.entries.enumerated().compactMap { index, entry in
      PackageInventoryRow(entry: entry, index: index)
    }
    guard let managerID else { return rows }
    return rows.filter { $0.managerID == managerID }
  }

  private init?(entry: BrewfileEntry, index: Int) {
    switch entry {
    case .tap(let name):
      self.init(
        index: index,
        managerID: "tap",
        kindLabel: "Tap",
        packageID: name,
        detail: "Repository",
        tierLabel: "Reference",
        cooldownWindow: "No package cooldown",
        promptLabel: "Not applicable",
        source: "brew tap",
        symbol: "point.3.connected.trianglepath.dotted"
      )
    case .brew(let name, let options):
      self.init(
        index: index,
        managerID: "brew",
        kindLabel: "Formula",
        packageID: name,
        detail: Self.optionsDetail(options),
        tier: .b,
        promptLabel: "Depends on tap",
        source: "brew",
        symbol: "terminal"
      )
    case .cask(let name, let options):
      self.init(
        index: index,
        managerID: "cask",
        kindLabel: "Cask",
        packageID: name,
        detail: Self.optionsDetail(options),
        tier: .c,
        promptLabel: "Depends on tap",
        source: "brew cask",
        symbol: "app.dashed"
      )
    case .mas(let name, let id):
      self.init(
        index: index,
        managerID: "mas",
        kindLabel: "App Store",
        packageID: name,
        detail: "id \(id)",
        tier: .a,
        promptLabel: "Not required",
        source: "mas",
        symbol: "apple.logo"
      )
    case .vscode(let name):
      self.init(
        index: index,
        managerID: "vscode",
        kindLabel: "VS Code",
        packageID: name,
        detail: "Extension",
        tier: .d,
        promptLabel: "Required before apply",
        source: "code",
        symbol: "curlybraces.square"
      )
    case .go(let name):
      self.init(
        index: index,
        managerID: "go",
        kindLabel: "Go",
        packageID: name,
        detail: "Module binary",
        tier: .e,
        promptLabel: "Required before apply",
        source: "go",
        symbol: "g.circle"
      )
    case .cargo(let name):
      self.init(
        index: index,
        managerID: "cargo",
        kindLabel: "Cargo",
        packageID: name,
        detail: "Rust package",
        tier: .e,
        promptLabel: "Required before apply",
        source: "cargo",
        symbol: "shippingbox"
      )
    case .uv(let name):
      self.init(
        index: index,
        managerID: "uv",
        kindLabel: "uv",
        packageID: name,
        detail: "Python tool",
        tier: .e,
        promptLabel: "Required before apply",
        source: "uv",
        symbol: "chevron.left.forwardslash.chevron.right"
      )
    case .krew(let name):
      self.init(
        index: index,
        managerID: "krew",
        kindLabel: "krew",
        packageID: name,
        detail: "kubectl plugin",
        tier: .e,
        promptLabel: "Required before apply",
        source: "kubectl krew",
        symbol: "k.square"
      )
    case .npm(let name):
      self.init(
        index: index,
        managerID: "npm",
        kindLabel: "npm",
        packageID: name,
        detail: "Global package",
        tier: .e,
        promptLabel: "Required before apply",
        source: "npm",
        symbol: "curlybraces"
      )
    case .flatpak(let name):
      self.init(
        index: index,
        managerID: "flatpak",
        kindLabel: "Flatpak",
        packageID: name,
        detail: "Application",
        tier: .e,
        promptLabel: "Required before apply",
        source: "flatpak",
        symbol: "shippingbox.circle"
      )
    case .comment, .blank:
      return nil
    }
  }

  private init(
    index: Int,
    managerID: String,
    kindLabel: String,
    packageID: String,
    detail: String,
    tier: BrewfileTier,
    promptLabel: String,
    source: String,
    symbol: String
  ) {
    self.init(
      index: index,
      managerID: managerID,
      kindLabel: kindLabel,
      packageID: packageID,
      detail: detail,
      tierLabel: tier.rawValue.uppercased(),
      cooldownWindow: Self.cooldownWindow(for: tier),
      promptLabel: promptLabel,
      source: source,
      symbol: symbol
    )
  }

  private init(
    index: Int,
    managerID: String,
    kindLabel: String,
    packageID: String,
    detail: String,
    tierLabel: String,
    cooldownWindow: String,
    promptLabel: String,
    source: String,
    symbol: String
  ) {
    self.id = "\(index)-\(managerID)-\(packageID)"
    self.managerID = managerID
    self.kindLabel = kindLabel
    self.packageID = packageID
    self.detail = detail
    self.tierLabel = tierLabel
    self.cooldownWindow = cooldownWindow
    self.promptLabel = promptLabel
    self.source = source
    self.symbol = symbol
  }

  private static func optionsDetail(_ options: [String: String]) -> String {
    guard !options.isEmpty else { return "No options" }
    return options
      .sorted { $0.key < $1.key }
      .map { "\($0.key): \($0.value)" }
      .joined(separator: ", ")
  }

  private static func cooldownWindow(for tier: BrewfileTier) -> String {
    let days = tier.defaultCooldownDays
    return days == 1 ? "1 day" : "\(days) days"
  }
}
