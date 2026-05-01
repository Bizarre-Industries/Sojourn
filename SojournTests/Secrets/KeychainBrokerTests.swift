// KeychainBrokerTests — smoke coverage for the v0.1 SecretBroker
// scaffold. Stage 14 wires Security.framework calls; v0.1 confirms the
// broker advertises itself as available and surfaces unsupported errors
// for read/write so the registry detection ladder behaves predictably.
// Audit §3.1.7 + ADR-0011.

import Foundation
@testable import Sojourn
import Testing

@Suite("KeychainBroker")
struct KeychainBrokerTests {
  @Test("brokerID is `keychain` and isAvailable returns true on macOS")
  func availability() async {
    let broker = KeychainBroker()
    let id = await broker.brokerID
    #expect(id == "keychain")
    let avail = await broker.isAvailable()
    #expect(avail == true)
  }

  @Test("list returns empty before Stage 14 wires SecItemCopyMatching")
  func listEmpty() async throws {
    let broker = KeychainBroker()
    let refs = try await broker.list()
    #expect(refs.isEmpty)
  }

  @Test("read throws unsupported until Stage 14")
  func readUnsupported() async {
    let broker = KeychainBroker()
    await #expect(throws: SecretBrokerError.self) {
      _ = try await broker.read(reference: "keychain://com.example/account")
    }
  }
}
