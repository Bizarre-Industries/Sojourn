// Sojourn — DiagnosticBundle model.
//
// Audit §3.1.5. Manifest of what `LogExporter` packed into a tarball.
// The user opens the bundle from `DiagnosticsPane.export` and sends
// it to a maintainer for triage.

import Foundation

internal struct DiagnosticBundle: Sendable, Hashable, Codable {
  internal let id: UUID
  internal let createdAt: Date
  internal let appVersion: String
  internal let osVersion: String
  internal let hostHash: String              // SHA-256 of the hostname
  internal let toolReport: ToolReportSummary
  internal let lineCount: Int
  internal let redactionApplied: Bool

  internal init(
    id: UUID = UUID(),
    createdAt: Date = Date(),
    appVersion: String,
    osVersion: String,
    hostHash: String,
    toolReport: ToolReportSummary,
    lineCount: Int,
    redactionApplied: Bool
  ) {
    self.id = id
    self.createdAt = createdAt
    self.appVersion = appVersion
    self.osVersion = osVersion
    self.hostHash = hostHash
    self.toolReport = toolReport
    self.lineCount = lineCount
    self.redactionApplied = redactionApplied
  }
}

internal struct ToolReportSummary: Sendable, Hashable, Codable {
  internal let git: Bool
  internal let brew: Bool
  internal let chezmoi: Bool
  internal let age: Bool
  internal let gitleaks: Bool
  internal let hasXcodeCLT: Bool
}
