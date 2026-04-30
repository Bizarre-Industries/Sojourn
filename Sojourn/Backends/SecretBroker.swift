// Sojourn — SecretBroker protocol.
//
// Audit §2.6 + §3.2.4. ADR-0011 makes 1Password CLI primary, age fallback.
// Each broker conforms; `SecretBrokerLadder` (Stage 14) chains them in
// detection order: 1Password → Bitwarden → Keychain → age → refuse.

import Foundation

internal protocol SecretBroker: Sendable {
  /// Stable broker id. "op" / "bw" / "keychain" / "age".
  var brokerID: String { get }

  /// Whether the broker is currently usable (CLI installed, key on disk,
  /// account session active, etc.). Probed during Bootstrap.
  func isAvailable() async -> Bool

  /// Read a secret by reference. References are broker-specific:
  ///   1Password: `op://vault/item/field`
  ///   Bitwarden: `bw://itemId/field`
  ///   Keychain:  `keychain://service/account`
  ///   age:       `age://path/to/encrypted/file`
  func read(reference: String) async throws -> String

  /// Write a secret. Brokers that don't support write throw `.unsupported`.
  func write(reference: String, value: String) async throws

  /// List references the user owns (for the secret-reference wizard).
  func list() async throws -> [SecretReference]
}

internal struct SecretReference: Sendable, Hashable, Codable, Identifiable {
  internal var id: String { reference }
  internal let reference: String
  internal let brokerID: String
  internal let label: String
  internal let kind: String          // "totp" | "password" | "ssh-key" | "api-key" | …
}

internal enum SecretBrokerError: Error, Sendable {
  case unsupported(broker: String, op: String)
  case notAvailable(broker: String)
  case referenceMalformed(String)
  case lookupFailed(String)
}
