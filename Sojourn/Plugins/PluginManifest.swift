// Sojourn — PluginManifest model.
//
// Audit §3.1.9 + ADR-0013. Each `~/Library/Application Support/Sojourn/
// plugins/<id>.sojourn-plugin/manifest.toml` decodes to this type.
//
// Schema is intentionally narrow today — Stage 14 wires actual loading;
// future plugin protocol revisions bump `manifestVersion` and gain new
// fields.

import Foundation

internal struct PluginManifest: Sendable, Hashable, Codable {
  internal let manifestVersion: Int           // schema version, currently 1
  internal let id: String                     // reverse-DNS, e.g. app.bizarre.sojourn-plugins.mise
  internal let version: String                // plugin semver
  internal let apiVersion: String             // plugin protocol version, e.g. "1.0"
  internal let name: String
  internal let description: String?
  internal let author: String?
  internal let capabilities: [String]         // ["package:list", "package:install", …]
  internal let executable: String             // relative path inside plugin dir
  internal let signature: String?             // cosign signature filename, optional in dev

  internal init(
    manifestVersion: Int = 1,
    id: String,
    version: String,
    apiVersion: String = "1.0",
    name: String,
    description: String? = nil,
    author: String? = nil,
    capabilities: [String] = [],
    executable: String,
    signature: String? = nil
  ) {
    self.manifestVersion = manifestVersion
    self.id = id
    self.version = version
    self.apiVersion = apiVersion
    self.name = name
    self.description = description
    self.author = author
    self.capabilities = capabilities
    self.executable = executable
    self.signature = signature
  }
}

internal enum PluginCapability: String, Sendable, Codable {
  case packageList    = "package:list"
  case packageInstall = "package:install"
  case packageRemove  = "package:remove"
  case packageUpgrade = "package:upgrade"
  case secretRead     = "secret:read"
  case secretList     = "secret:list"
}
