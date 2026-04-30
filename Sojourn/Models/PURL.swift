// Sojourn — Package URL (purl) value type.
//
// Per spec: <https://github.com/package-url/purl-spec>
// Format: pkg:type/namespace/name@version?qualifiers#subpath
//
// Audit §2.1.2: PURL specifiers in `packages.toml` per-machine override
// schema disambiguate same-name packages across managers. Stage 10 wires
// PURL parsing into the mpm round-trip.

import Foundation

internal struct PURL: Hashable, Sendable, Codable {
  internal let type: String
  internal let namespace: String?
  internal let name: String
  internal let version: String?
  internal let qualifiers: [String: String]
  internal let subpath: String?

  internal init(
    type: String,
    namespace: String? = nil,
    name: String,
    version: String? = nil,
    qualifiers: [String: String] = [:],
    subpath: String? = nil
  ) {
    self.type = type.lowercased()
    self.namespace = namespace
    self.name = name
    self.version = version
    self.qualifiers = qualifiers
    self.subpath = subpath
  }

  internal var canonicalString: String {
    var s = "pkg:\(type)/"
    if let ns = namespace {
      s += "\(ns)/"
    }
    s += name
    if let v = version {
      s += "@\(v)"
    }
    if !qualifiers.isEmpty {
      let q = qualifiers
        .sorted { $0.key < $1.key }
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: "&")
      s += "?\(q)"
    }
    if let sub = subpath {
      s += "#\(sub)"
    }
    return s
  }
}

internal enum PURLParseError: Error {
  case missingScheme
  case missingType
  case missingName
}

extension PURL {
  /// Parse a purl string. Strict — extra whitespace is not tolerated.
  internal static func parse(_ raw: String) throws -> PURL {
    guard raw.hasPrefix("pkg:") else { throw PURLParseError.missingScheme }
    var rest = String(raw.dropFirst("pkg:".count))

    var subpath: String? = nil
    if let hashIndex = rest.firstIndex(of: "#") {
      subpath = String(rest[rest.index(after: hashIndex)...])
      rest = String(rest[..<hashIndex])
    }

    var qualifiers: [String: String] = [:]
    if let qmark = rest.firstIndex(of: "?") {
      let qstring = String(rest[rest.index(after: qmark)...])
      rest = String(rest[..<qmark])
      for pair in qstring.split(separator: "&") {
        let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
        if kv.count == 2 {
          qualifiers[kv[0]] = kv[1]
        }
      }
    }

    var version: String? = nil
    if let atIndex = rest.lastIndex(of: "@") {
      version = String(rest[rest.index(after: atIndex)...])
      rest = String(rest[..<atIndex])
    }

    let parts = rest.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard let type = parts.first, !type.isEmpty else { throw PURLParseError.missingType }
    let after = Array(parts.dropFirst())
    guard let last = after.last, !last.isEmpty else { throw PURLParseError.missingName }

    let namespaceParts = after.dropLast()
    let namespace = namespaceParts.isEmpty ? nil : namespaceParts.joined(separator: "/")

    return PURL(
      type: type,
      namespace: namespace,
      name: last,
      version: version,
      qualifiers: qualifiers,
      subpath: subpath
    )
  }
}
