import Foundation

/// Wraps bundled gitleaks binary. Runs before every auto-commit.
/// See docs/ARCHITECTURE.md section 5.3 and section 10.
actor SecretScanService {
  init() {}
}

/// A single gitleaks finding decoded from the JSON report.
struct SecretFinding: Sendable, Codable, Equatable {
  let ruleID: String
  let description: String
  let file: String
  let line: Int
  let commit: String?
  let author: String?
  let email: String?
  let date: String?
  let match: String
  let secret: String

  enum CodingKeys: String, CodingKey {
    case ruleID = "RuleID"
    case description = "Description"
    case file = "File"
    case line = "StartLine"
    case commit = "Commit"
    case author = "Author"
    case email = "Email"
    case date = "Date"
    case match = "Match"
    case secret = "Secret"
  }
}
