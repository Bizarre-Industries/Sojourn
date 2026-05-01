// Sojourn — LogExporter actor.
//
// Audit §3.1.5. Builds a directory of redacted logs + JSON manifest
// for support triage. Today: writes plain dir tree. Stage 15 wraps
// the dir into a `.tar.gz` for the user's "Export bundle" button.
//
// Privacy contract: every log line passes through `Redactor.redact(_:)`
// before serialization. Hostname is SHA-256 hashed in the manifest;
// `/Users/<name>` paths are scrubbed to `/Users/<USER>`; high-confidence
// secret patterns become placeholders.

import CryptoKit
import Foundation

internal actor LogExporter {
  private let redactor: Redactor

  internal init(redactor: Redactor = Redactor()) {
    self.redactor = redactor
  }

  /// Export `lines` to a fresh directory under `destination`. Returns the
  /// directory URL the bundle was written to.
  internal func export(
    lines: [String],
    toolReport: ToolReportSummary,
    appVersion: String,
    osVersion: String,
    destination: URL
  ) async throws -> URL {
    let bundleID = UUID()
    let dir = destination.appendingPathComponent(bundleID.uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    // Redact every line.
    let redacted = lines.map { redactor.redact($0) }
    let logURL = dir.appendingPathComponent("redacted.log")
    try redacted.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)

    // Build manifest.
    let bundle = DiagnosticBundle(
      id: bundleID,
      createdAt: Date(),
      appVersion: appVersion,
      osVersion: osVersion,
      hostHash: Self.sha256(of: redactor.host),
      toolReport: toolReport,
      lineCount: redacted.count,
      redactionApplied: true
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let manifestData = try encoder.encode(bundle)
    try manifestData.write(to: dir.appendingPathComponent("manifest.json"), options: .atomic)

    return dir
  }

  // MARK: - Helpers

  private static func sha256(of input: String) -> String {
    let data = Data(input.utf8)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
