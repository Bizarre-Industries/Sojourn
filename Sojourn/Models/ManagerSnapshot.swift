// Sojourn — ManagerSnapshot
//
// Decoded shape of `mpm 6.x --table-format json`. One entry per package
// manager (brew, cask, mas, pip, pipx, npm, cargo, gem, composer, yarn,
// vscode, uvx). See docs/ARCHITECTURE.md §5.1 and the golden fixture at
// SojournTests/Fixtures/mpm-installed.json.

import Foundation

public struct ManagerSnapshot: Sendable, Codable, Hashable, Identifiable {
  public let id: String
  public let name: String
  public let errors: [String]
  public let packages: [ManagedPackage]

  public init(
    id: String,
    name: String,
    errors: [String] = [],
    packages: [ManagedPackage] = []
  ) {
    self.id = id
    self.name = name
    self.errors = errors
    self.packages = packages
  }
}

public struct ManagedPackage: Sendable, Codable, Hashable, Identifiable {
  public let id: String
  public let name: String?
  public let installedVersion: String?
  public let latestVersion: String?

  public init(
    id: String,
    name: String? = nil,
    installedVersion: String? = nil,
    latestVersion: String? = nil
  ) {
    self.id = id
    self.name = name
    self.installedVersion = installedVersion
    self.latestVersion = latestVersion
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case installedVersion = "installed_version"
    case latestVersion = "latest_version"
  }
}
