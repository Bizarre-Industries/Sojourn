// RedactorTests — smoke coverage for diagnostic-bundle PII/secret
// scrubbing. Audit §3.1.5.

import Foundation
@testable import Sojourn
import Testing

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

  @Test("masks current GitHub token formats")
  func currentGitHubTokenFormats() {
    let r = Redactor(username: "alice", host: "synthetic-host-9001")
    let tokens = [
      ("github_pat_EXAMPLE" + String(repeating: "A", count: 75), "<GITHUB_FINE_GRAINED_PAT>"),
      ("ghu_EXAMPLE" + String(repeating: "B", count: 30), "<GITHUB_APP_USER_TOKEN>"),
      ("ghr_EXAMPLE" + String(repeating: "C", count: 30), "<GITHUB_APP_REFRESH_TOKEN>"),
      ("ghs_123456_EXAMPLE" + String(repeating: "D", count: 110) + "." + String(repeating: "E", count: 110), "<GITHUB_APP_TOKEN>")
    ]

    for (token, replacement) in tokens {
      let out = r.redact("token=\(token) end")
      #expect(out.contains(replacement))
      #expect(!out.contains(token))
    }
  }
}
