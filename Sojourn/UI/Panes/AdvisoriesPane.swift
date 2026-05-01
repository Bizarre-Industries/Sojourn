// Sojourn — AdvisoriesPane (v0.2 step 10)
//
// First-class UI over `AdvisoryService`. Header surfaces the
// three-state freshness indicator; table lists CVEs with severity +
// summary + reference link.
//
// Refs: ADR-0021; docs/process/plans/v0.2-plan.md step 10.

import Foundation
import SwiftUI

internal struct AdvisoriesPane: View {
  @Environment(AppStore.self) private var store
  @State private var snapshot: AdvisorySnapshot?
  @State private var refreshing: Bool = false
  @State private var lastError: String?

  internal var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      if let lastError {
        Text(lastError)
          .font(.system(size: 13, design: .monospaced))
          .foregroundStyle(.red)
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
      }
      list
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityIdentifier("pane.advisories")
    .task { await loadCached() }
  }

  // MARK: - Subviews

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Advisories")
          .font(.system(size: 22, weight: .bold))
        freshnessLine
      }
      Spacer()
      Button {
        Task { await runRefresh() }
      } label: {
        if refreshing {
          ProgressView().controlSize(.small)
        } else {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
      }
      .disabled(refreshing)
    }
  }

  @ViewBuilder
  private var freshnessLine: some View {
    let f = snapshot?.freshness ?? .unavailable
    let lastSuccess = snapshot?.lastSuccessAt
    HStack(spacing: 6) {
      Circle()
        .fill(color(for: f))
        .frame(width: 8, height: 8)
      Text(message(for: f, lastSuccess: lastSuccess))
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
  }

  private var list: some View {
    let items = snapshot?.advisories ?? []
    return Group {
      if items.isEmpty {
        emptyState
      } else {
        Table(items) {
          TableColumn("Severity") { adv in
            Text(adv.severity.rawValue.uppercased())
              .font(.system(size: 11, weight: .bold, design: .monospaced))
              .foregroundStyle(severityColor(adv.severity))
          }
          .width(70)

          TableColumn("ID") { adv in
            Text(adv.id)
              .font(.system(size: 12, design: .monospaced))
          }
          .width(min: 140, ideal: 180)

          TableColumn("Summary") { adv in
            Text(adv.summary)
              .font(.system(size: 12))
              .lineLimit(2)
          }

          TableColumn("Affected") { adv in
            Text(adv.affectedPackages.map(\.name).joined(separator: ", "))
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          .width(min: 120, ideal: 160)
        }
      }
    }
  }

  private var emptyState: some View {
    let f = snapshot?.freshness ?? .unavailable
    return VStack(spacing: 8) {
      Image(systemName: f == .fresh ? "checkmark.shield" : "exclamationmark.shield")
        .font(.system(size: 32, weight: .medium))
        .foregroundStyle(f == .fresh ? .green : .secondary)
      Text(emptyTitle(for: f))
        .font(.system(size: 14, weight: .medium))
      Text(emptyBody(for: f))
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 480)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Actions

  private func makeService() -> AdvisoryService {
    let cache = store.paths.cache.appendingPathComponent("advisories.json")
    let resolvedBrew = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
      ? URL(fileURLWithPath: "/opt/homebrew/bin/brew")
      : URL(fileURLWithPath: "/usr/local/bin/brew")
    return AdvisoryService(
      runner: store.runner,
      brewURL: resolvedBrew,
      chezmoiSourceRoot: nil,
      cacheURL: cache
    )
  }

  private func loadCached() async {
    let svc = makeService()
    await svc.loadFromDisk()
    snapshot = await svc.currentSnapshot()
  }

  private func runRefresh() async {
    refreshing = true
    defer { refreshing = false }
    let svc = makeService()
    let brewfile = store.paths.config.appendingPathComponent("Brewfile.common")
    do {
      let updated = try await svc.refresh(brewfile: brewfile)
      snapshot = updated
      lastError = nil
    } catch {
      snapshot = await svc.currentSnapshot()
      lastError = "Refresh failed: \(error)"
    }
  }

  // MARK: - Format helpers

  private func color(for f: AdvisoryFreshness) -> Color {
    switch f {
    case .fresh:       return .green
    case .stale:       return .orange
    case .unavailable: return .gray
    }
  }

  private func message(for f: AdvisoryFreshness, lastSuccess: Date?) -> String {
    switch f {
    case .fresh:
      if let last = lastSuccess {
        return "Last refreshed \(last.formatted(.relative(presentation: .named)))."
      }
      return "Fresh."
    case .stale:
      if let last = lastSuccess {
        return "Last refreshed \(last.formatted(.relative(presentation: .named))). Tap Refresh to retry."
      }
      return "Stale. Tap Refresh to retry."
    case .unavailable:
      return "Advisories not yet checked. Run Refresh to query brew vulns."
    }
  }

  private func severityColor(_ s: AdvisorySeverity) -> Color {
    switch s {
    case .critical: return .red
    case .high:     return .orange
    case .moderate: return .yellow
    case .low:      return .secondary
    }
  }

  private func emptyTitle(for f: AdvisoryFreshness) -> String {
    switch f {
    case .fresh:       return "No advisories."
    case .stale:       return "No cached advisories."
    case .unavailable: return "Advisories not checked."
    }
  }

  private func emptyBody(for f: AdvisoryFreshness) -> String {
    switch f {
    case .fresh:
      return "Your Brewfile entries have no known vulnerabilities according to OSV.dev."
    case .stale:
      return "The last refresh failed; cached results aren't available. Try again."
    case .unavailable:
      return "Sojourn calls `brew vulns --brewfile Brewfile --cyclonedx` to fetch CVE data from OSV.dev. The homebrew/brew-vulns tap must be installed (Sojourn prompts for consent on first refresh)."
    }
  }
}
