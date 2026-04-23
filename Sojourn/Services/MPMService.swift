import Foundation

/// Wraps meta-package-manager (mpm). Pin to 6.x; uses --table-format json.
/// See docs/ARCHITECTURE.md section 5.1.
actor MPMService {
  init() {}
}

/// Per-manager snapshot as returned by mpm --table-format json installed/outdated.
struct ManagerSnapshot: Sendable, Codable, Equatable {
  let id: String
  let name: String?
  let errors: [String]
  let packages: [PackageRecord]
}

struct PackageRecord: Sendable, Codable, Equatable {
  let id: String
  let name: String?
  let installedVersion: String?
  let latestVersion: String?

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case installedVersion = "installed_version"
    case latestVersion = "latest_version"
  }
}
