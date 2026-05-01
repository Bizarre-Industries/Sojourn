// Sojourn — CycloneDX SBOM model (subset).
//
// Audit §2.1.1. Every push writes `sbom.cyclonedx.json` next to
// `packages.toml`. Spec: <https://cyclonedx.org/specification/overview/>
//
// We model only the fields Sojourn writes today. Stage 10 fills in
// `components` from `brew vulns --brewfile <path> --cyclonedx` output;
// the file is `Codable` so consumers (Advisories pane, future OSV
// cross-reference) can round-trip without re-shelling.

import Foundation

internal struct CycloneDX: Sendable, Hashable, Codable {
  internal let bomFormat: String        // always "CycloneDX"
  internal let specVersion: String      // "1.5"
  internal let serialNumber: String     // "urn:uuid:..."
  internal let version: Int             // bom revision
  internal let metadata: Metadata
  internal let components: [Component]

  internal init(
    serialNumber: String = "urn:uuid:\(UUID().uuidString.lowercased())",
    version: Int = 1,
    metadata: Metadata,
    components: [Component]
  ) {
    self.bomFormat = "CycloneDX"
    self.specVersion = "1.5"
    self.serialNumber = serialNumber
    self.version = version
    self.metadata = metadata
    self.components = components
  }

  internal struct Metadata: Sendable, Hashable, Codable {
    internal let timestamp: Date
    internal let tools: [Tool]
  }

  internal struct Tool: Sendable, Hashable, Codable {
    internal let vendor: String
    internal let name: String
    internal let version: String?
  }

  internal struct Component: Sendable, Hashable, Codable {
    internal let bomRef: String?
    internal let type: String           // "library" | "application" | "framework"
    internal let name: String
    internal let version: String?
    internal let purl: String?

    internal enum CodingKeys: String, CodingKey {
      case bomRef = "bom-ref"
      case type
      case name
      case version
      case purl
    }
  }
}
