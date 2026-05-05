// Sojourn — SecretScanService
//
// Pre-commit secret scanning via bundled gitleaks at
// `Contents/Resources/bin/gitleaks` (inside the .app) or
// `Sojourn/Resources/bin/gitleaks` (when run from source). Flow + tiers
// are specified in SECURITY.md (Pre-commit secret scanning).

import Foundation

internal struct SecretFinding: Sendable, Hashable, Codable, Identifiable {
  internal var id: String { fingerprint }
  internal let description: String
  internal let file: String
  internal let startLine: Int
  internal let endLine: Int
  internal let match: String
  internal let secret: String
  internal let ruleID: String
  internal let fingerprint: String
  internal let entropy: Double?

  internal enum CodingKeys: String, CodingKey {
    case description = "Description"
    case file = "File"
    case startLine = "StartLine"
    case endLine = "EndLine"
    case match = "Match"
    case secret = "Secret"
    case ruleID = "RuleID"
    case fingerprint = "Fingerprint"
    case entropy = "Entropy"
  }

  /// High-confidence provider-key rules that must block the user for 5s
  /// per SECURITY.md.
  internal var isHighConfidence: Bool {
    let blocking: Set<String> = [
      "aws-access-token",
      "aws-access-key",
      "github-pat",
      "github-fine-grained-pat",
      "github-oauth-token",
      "github-app-user-token",
      "github-app-token",
      "github-app-refresh-token",
      "openai-api-key",
      "stripe-access-token",
      "stripe-live",
      "anthropic-api-key",
      "slack-bot-token",
      "slack-user-token",
      "sojourn-aws-access-key",
      "sojourn-github-pat",
      "sojourn-github-fine-grained-pat",
      "sojourn-github-oauth-token",
      "sojourn-github-app-user-token",
      "sojourn-github-app-installation-token",
      "sojourn-github-app-refresh-token",
      "sojourn-openai-key",
      "sojourn-stripe-live",
      "sojourn-anthropic-key",
      "sojourn-slack-bot-token"
    ]
    return blocking.contains(ruleID)
  }
}

internal enum SecretScanError: Error, Sendable {
  case binaryNotFound(URL)
  case decodeFailed(String)
  case reportTooLarge(bytes: Int, limit: Int)
}

internal actor SecretScanService {
  internal static let jsonReportSizeLimit = 10_000_000

  internal typealias Runner = @Sendable ([String], URL?) async throws -> SubprocessResult

  private let runCommand: Runner
  private let decoder: JSONDecoder
  internal let gitleaksURL: URL
  internal let configURL: URL?

  internal init(gitleaksURL: URL, configURL: URL? = nil, runCommand: @escaping Runner) {
    self.gitleaksURL = gitleaksURL
    self.configURL = configURL
    self.runCommand = runCommand
    self.decoder = JSONDecoder()
  }

  internal static func live(runner: SubprocessRunner, configURL: URL? = nil) -> SecretScanService? {
    let candidates: [URL] = [
      Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bin/gitleaks"),
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sojourn/Resources/bin/gitleaks")
    ]
    guard let found = candidates.first(where: {
      FileManager.default.isExecutableFile(atPath: $0.path)
    }) else {
      return nil
    }
    guard let effectiveConfigURL = configURL ?? bundledConfigURL() else {
      return nil
    }
    return SecretScanService(gitleaksURL: found, configURL: effectiveConfigURL, runCommand: { args, cwd in
      try await runner.run(
        tool: found,
        args: args,
        cwd: cwd,
        timeout: 60,
        outputLimitBytes: Self.jsonReportSizeLimit
      )
    })
  }

  internal static func bundledConfigURL() -> URL? {
    let candidates: [URL] = [
      Bundle.main.bundleURL
        .appendingPathComponent("Contents/Resources/data/gitleaks.toml"),
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sojourn/Resources/data/gitleaks.toml")
    ]
    return candidates.first {
      FileManager.default.fileExists(atPath: $0.path)
    }
  }

  internal static func mock(
    response: @escaping @Sendable ([String]) async throws -> Data
  ) -> SecretScanService {
    SecretScanService(
      gitleaksURL: URL(fileURLWithPath: "/usr/local/bin/gitleaks"),
      runCommand: { args, _ in
        let data = try await response(args)
        return SubprocessResult(exitCode: 0, stdout: data, stderr: Data())
      }
    )
  }

  // MARK: - Public

  internal func scanDirectory(_ dir: URL) async throws -> [SecretFinding] {
    var args = [
      "dir", "--report-format", "json", "--report-path", "-",
      "--redact", "--exit-code=0"
    ]
    if let configURL {
      args.append(contentsOf: ["--config", configURL.path])
    }
    args.append(dir.path)
    let result = try await runCommand(args, nil)
    return try decode(result.stdout)
  }

  internal func scanStaged(cwd: URL) async throws -> [SecretFinding] {
    var args = [
      "git", "--staged", "--report-format", "json", "--report-path", "-",
      "--redact", "--exit-code=0"
    ]
    if let configURL {
      args.append(contentsOf: ["--config", configURL.path])
    }
    let result = try await runCommand(args, cwd)
    return try decode(result.stdout)
  }

  // MARK: - Private

  private func decode(_ data: Data) throws -> [SecretFinding] {
    if data.isEmpty { return [] }
    guard data.count <= Self.jsonReportSizeLimit else {
      throw SecretScanError.reportTooLarge(bytes: data.count, limit: Self.jsonReportSizeLimit)
    }
    do {
      return try decoder.decode([SecretFinding].self, from: data)
    } catch {
      let preview = String(decoding: data.prefix(200), as: UTF8.self)
      throw SecretScanError.decodeFailed(preview)
    }
  }
}
