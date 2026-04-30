// Sojourn — PluginProtocol method names + JSON-RPC envelope.
//
// Audit §3.1.9 + ADR-0013. JSON-RPC 2.0 over stdio. Stage 14 ships
// `PluginRunner` which serializes requests on these method names and
// awaits responses from the plugin subprocess.

import Foundation

internal enum PluginRPC {
  // MARK: - Lifecycle
  static let handshake = "plugin.handshake"
  static let shutdown  = "plugin.shutdown"

  // MARK: - PackageBackend mirror
  static let packageInstalled = "package.installed"
  static let packageOutdated  = "package.outdated"
  static let packageInstall   = "package.install"
  static let packageRemove    = "package.remove"
  static let packageUpgrade   = "package.upgrade"
  static let packageSearch    = "package.search"

  // MARK: - SecretBroker mirror
  static let secretRead = "secret.read"
  static let secretList = "secret.list"
}

/// JSON-RPC 2.0 request envelope (outbound).
internal struct PluginRequest: Sendable, Codable {
  internal let jsonrpc: String
  internal let id: String
  internal let method: String
  internal let params: [String: PluginValue]?

  internal init(method: String, params: [String: PluginValue]? = nil) {
    self.jsonrpc = "2.0"
    self.id = UUID().uuidString
    self.method = method
    self.params = params
  }
}

/// JSON-RPC 2.0 response envelope (inbound).
internal struct PluginResponse: Sendable, Codable {
  internal let jsonrpc: String
  internal let id: String?
  internal let result: PluginValue?
  internal let error: PluginErrorEnvelope?
}

internal struct PluginErrorEnvelope: Sendable, Codable {
  internal let code: Int
  internal let message: String
  internal let data: PluginValue?
}

/// Type-erased JSON value used for params and results.
internal indirect enum PluginValue: Sendable, Codable, Hashable {
  case null
  case bool(Bool)
  case int(Int)
  case double(Double)
  case string(String)
  case array([PluginValue])
  case object([String: PluginValue])

  internal init(from decoder: any Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil()                                     { self = .null;       return }
    if let v = try? c.decode(Bool.self)                  { self = .bool(v);    return }
    if let v = try? c.decode(Int.self)                   { self = .int(v);     return }
    if let v = try? c.decode(Double.self)                { self = .double(v);  return }
    if let v = try? c.decode(String.self)                { self = .string(v);  return }
    if let v = try? c.decode([PluginValue].self)         { self = .array(v);   return }
    if let v = try? c.decode([String: PluginValue].self) { self = .object(v);  return }
    throw DecodingError.dataCorruptedError(in: c, debugDescription: "PluginValue")
  }

  internal func encode(to encoder: any Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .null:           try c.encodeNil()
    case .bool(let v):    try c.encode(v)
    case .int(let v):     try c.encode(v)
    case .double(let v):  try c.encode(v)
    case .string(let v):  try c.encode(v)
    case .array(let v):   try c.encode(v)
    case .object(let v):  try c.encode(v)
    }
  }
}
