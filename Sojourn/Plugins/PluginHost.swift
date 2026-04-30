// Sojourn — PluginHost actor.
//
// Audit §3.1.9 + ADR-0013. Discovers plugin directories, decodes their
// manifests, hands them to the verifier, and registers verified plugins
// into the BackendRegistry as `PackageBackend` (or `SecretBroker`)
// adapters.
//
// Stage 8: ships discovery + manifest read scaffold. Stage 14 wires:
//   • cosign signature verification
//   • PluginRunner (JSON-RPC over stdio)
//   • registry adapter that bridges `PluginRunner` → `PackageBackend`

import Foundation

internal actor PluginHost {
  private let registry: BackendRegistry
  private var discovered: [PluginManifest] = []
  internal let pluginsRoot: URL

  internal init(registry: BackendRegistry, pluginsRoot: URL? = nil) {
    self.registry = registry
    if let pluginsRoot {
      self.pluginsRoot = pluginsRoot
    } else {
      let fm = FileManager.default
      let appSupport = (try? fm.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      )) ?? URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Application Support")
      self.pluginsRoot = appSupport.appendingPathComponent("Sojourn/plugins")
    }
  }

  /// Walk `pluginsRoot` for `*.sojourn-plugin/manifest.toml` files,
  /// populate `discovered`. Stage 8 returns an empty list until the
  /// TOML decode lands in Stage 14.
  internal func discover() async -> [PluginManifest] {
    let fm = FileManager.default
    guard let entries = try? fm.contentsOfDirectory(
      at: pluginsRoot,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      discovered = []
      return []
    }

    let found: [PluginManifest] = []
    for url in entries {
      guard url.pathExtension == "sojourn-plugin" else { continue }
      let manifestURL = url.appendingPathComponent("manifest.toml")
      guard let _ = try? String(contentsOf: manifestURL, encoding: .utf8) else { continue }
      // Stage 14: decode via `SojournFileCodec` and populate `found`.
      _ = manifestURL
    }

    discovered = found
    return found
  }

  /// Stage 14 wires verification + JSON-RPC adapter registration.
  /// Stage 8: throws `operationUnsupported`.
  internal func load(_ manifest: PluginManifest) async throws {
    throw BackendError.operationUnsupported(manifest.id, "PluginHost.load (Stage 14)")
  }

  internal var allDiscovered: [PluginManifest] { discovered }
}
