// RedactorTests — smoke coverage for diagnostic-bundle PII/secret
// scrubbing. Audit §3.1.5.

import Foundation
import Testing
@testable import Sojourn

@Suite("Redactor")
struct RedactorTests {

  @Test("scrubs username path prefix")
  func usernamePath() {
    let r = Redactor(username: "alice", host: "fake-host")
    let out = r.redact("opened /Users/alice/Documents/foo.txt")
    #expect(out.contains("/Users/<USER>"))
    #expect(!out.contains("/Users/alice"))
  }

  @Test("scrubs hostname")
  func hostName() {
    let r = Redactor(username: "alice", host: "alices-mac")
    let out = r.redact("connected to alices-mac.local")
    #expect(out.contains("<HOST>"))
    #expect(!out.contains("alices-mac"))
  }

  @Test("masks AWS access key id")
  func awsKey() {
    let r = Redactor(username: "alice", host: "synthetic-host-9001")
    let synthetic = "AKIA" + String(repeating: "A", count: 16)
    let out = r.redact("aws key=\(synthetic)")
    #expect(out.contains("<AWS_ACCESS_KEY_ID>"))
    #expect(!out.contains(synthetic))
  }

  @Test("masks GitHub PAT")
  func githubPat() {
    let r = Redactor(username: "alice", host: "synthetic-host-9001")
    let synthetic = "ghp_" + String(repeating: "x", count: 36)
    let out = r.redact("token=\(synthetic) end")
    #expect(out.contains("<GITHUB_PAT>"))
    #expect(!out.contains(synthetic))
  }
}
