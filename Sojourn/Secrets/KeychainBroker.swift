// Sojourn — KeychainBroker.
//
// Audit §3.1.7. Wraps macOS Keychain via `Security.framework` for the
// `keyring` template function. Reference scheme:
//   keychain://<service>/<account>
//
// Stage 8 ships the conformer skeleton that throws `.unsupported`;
// Stage 14 wires `SecItemCopyMatching` / `SecItemAdd` / `SecItemDelete`.

import Foundation

internal actor KeychainBroker: SecretBroker {
  internal let brokerID: String = "keychain"

  internal init() {}

  internal func isAvailable() async -> Bool {
    // Keychain is always available on macOS; per-item ACLs may still
    // refuse access, surfaced through `read(reference:)`.
    true
  }

  internal func read(reference: String) async throws -> String {
    throw SecretBrokerError.unsupported(broker: brokerID, op: "read")
  }

  internal func write(reference: String, value: String) async throws {
    throw SecretBrokerError.unsupported(broker: brokerID, op: "write")
  }

  internal func list() async throws -> [SecretReference] {
    []
  }
}
