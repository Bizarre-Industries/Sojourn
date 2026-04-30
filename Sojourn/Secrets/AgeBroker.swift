// Sojourn — AgeBroker.
//
// Audit §3.1.7. Stage 8 ships the protocol conformer skeleton; Stage 14
// finalizes the live `age` invocation path (decrypt with the user's key
// from `~/.config/sojourn/age.key`, re-encrypt to recipients).
//
// Reference scheme: `age://<repo-relative-path>`.

import Foundation

internal actor AgeBroker: SecretBroker {
  internal let brokerID: String = "age"

  private let runner: SubprocessRunner
  private let locator: ToolLocator
  private let identityFile: URL?

  internal init(
    runner: SubprocessRunner,
    locator: ToolLocator,
    identityFile: URL? = nil
  ) {
    self.runner = runner
    self.locator = locator
    self.identityFile = identityFile
  }

  internal func isAvailable() async -> Bool {
    guard await locator.locate("age")?.url != nil else { return false }
    if let id = identityFile {
      return FileManager.default.fileExists(atPath: id.path)
    }
    return true
  }

  internal func read(reference: String) async throws -> String {
    // Stage 14 wires `age --decrypt -i <identity> <path>` via SubprocessRunner.
    throw SecretBrokerError.unsupported(broker: brokerID, op: "read")
  }

  internal func write(reference: String, value: String) async throws {
    throw SecretBrokerError.unsupported(broker: brokerID, op: "write")
  }

  internal func list() async throws -> [SecretReference] {
    []
  }
}
