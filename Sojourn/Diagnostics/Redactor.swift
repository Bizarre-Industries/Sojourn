// Sojourn — Redactor.
//
// Audit §3.1.5. Strips user paths, host names, and high-confidence
// secret patterns from log lines before they leave the user's machine
// in a diagnostics export bundle.
//
// Patterns mirror the gitleaks ruleset (AWS / GitHub PAT / OpenAI /
// Stripe) plus Sojourn-specific paths.

import Foundation

internal struct Redactor: Sendable {
  internal let username: String
  internal let host: String

  internal init(
    username: String = NSUserName(),
    host: String = Host.current().localizedName ?? "host"
  ) {
    self.username = username
    self.host = host
  }

  internal func redact(_ input: String) -> String {
    var s = input

    // Path scrubbing
    s = s.replacingOccurrences(of: "/Users/\(username)", with: "/Users/<USER>")
    s = s.replacingOccurrences(of: "Users\\\(username)", with: "Users\\<USER>")
    s = s.replacingOccurrences(of: host, with: "<HOST>")

    // Secret-shaped tokens
    for (pattern, replacement) in Redactor.secretPatterns {
      s = s.replacing(regex: pattern, with: replacement)
    }
    return s
  }

  /// (regex, replacement) pairs. Conservative — false positives prefer
  /// over false negatives.
  internal static let secretPatterns: [(String, String)] = [
    ("AKIA[0-9A-Z]{16}", "<AWS_ACCESS_KEY_ID>"),
    ("ASIA[0-9A-Z]{16}", "<AWS_TEMP_KEY_ID>"),
    ("ghp_[0-9A-Za-z]{36}", "<GITHUB_PAT>"),
    ("gho_[0-9A-Za-z]{36}", "<GITHUB_OAUTH>"),
    ("ghs_[0-9A-Za-z]{36}", "<GITHUB_APP_TOKEN>"),
    ("sk-[0-9A-Za-z]{20,}", "<OPENAI_KEY>"),
    ("sk_(live|test)_[0-9A-Za-z]{24}", "<STRIPE_SECRET>"),
    ("xoxb-[0-9]{11,}-[0-9]{11,}-[A-Za-z0-9]{24}", "<SLACK_BOT_TOKEN>"),
    ("ya29\\.[0-9A-Za-z\\-_]+", "<GOOGLE_OAUTH>"),
    ("[a-f0-9]{40}@github\\.com", "<GITHUB_DEPLOY_KEY_FP>"),
    ("Bearer\\s+[A-Za-z0-9+/=._-]{16,}", "Bearer <TOKEN>")
  ]
}

private extension String {
  func replacing(regex: String, with replacement: String) -> String {
    guard let re = try? NSRegularExpression(pattern: regex, options: []) else {
      return self
    }
    let range = NSRange(startIndex..<endIndex, in: self)
    return re.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replacement)
  }
}
