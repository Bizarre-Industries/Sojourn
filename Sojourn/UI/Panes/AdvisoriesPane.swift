// Sojourn — AdvisoriesPane

import SwiftUI

struct AdvisoriesPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header

      if store.advisorySnapshot.advisories.isEmpty {
        ContentUnavailableView(
          "No advisory snapshot",
          systemImage: "exclamationmark.shield",
          description: Text(emptyDescription)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(store.advisorySnapshot.advisories) { advisory in
          advisoryRow(advisory)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
      }
    }
    .padding(24)
    .background(Color(nsColor: .windowBackgroundColor))
    .accessibilityIdentifier("pane.advisories")
    .task {
      await store.refreshAdvisorySnapshot()
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Advisories")
          .font(.title2.weight(.semibold))
        Text("Cached Homebrew vulnerability snapshot and cooldown-bypass signal.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      Label(freshnessLabel, systemImage: freshnessSymbol)
        .font(.caption)
        .foregroundStyle(.secondary)
      Button {
        Task { await store.refreshAdvisorySnapshot(force: true) }
      } label: {
        Label("Refresh Cache", systemImage: "arrow.clockwise")
      }
    }
  }

  private func advisoryRow(_ advisory: AdvisoryReference) -> some View {
    HStack(spacing: 12) {
      Image(systemName: advisory.triggersBypass ? "exclamationmark.octagon" : "exclamationmark.triangle")
        .foregroundStyle(color(for: advisory.severity))
        .frame(width: 22)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(advisory.id)
          .font(.callout.weight(.semibold))
        Text(advisory.summary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      Text(advisory.severity.rawValue.capitalized)
        .font(.caption)
        .foregroundStyle(color(for: advisory.severity))
    }
    .padding(.vertical, 5)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(advisory.id). \(advisory.severity.rawValue.capitalized). \(advisory.summary).")
  }

  private var emptyDescription: String {
    store.advisoryMessage
      ?? advisoryDetail
  }

  private var advisoryDetail: String {
    switch store.advisorySnapshot.freshness {
    case .fresh:
      return "Fresh cached advisory snapshot. \(snapshotDates)"
    case .stale:
      return "Cached advisory snapshot is stale. \(snapshotDates)"
    case .unavailable:
      return "No cached advisory snapshot. Configure Homebrew vulnerability data with consent, then refresh this pane."
    }
  }

  private var snapshotDates: String {
    let success = store.advisorySnapshot.lastSuccessAt
      .map { "Last success \(Self.dateFormatter.localizedString(for: $0, relativeTo: Date()))." }
      ?? "No successful scan recorded."
    let attempt = store.advisorySnapshot.lastAttemptAt
      .map { "Last attempt \(Self.dateFormatter.localizedString(for: $0, relativeTo: Date()))." }
      ?? "No scan attempt recorded."
    return "\(success) \(attempt)"
  }

  private var freshnessLabel: String {
    switch store.advisorySnapshot.freshness {
    case .fresh:       return "Fresh"
    case .stale:       return "Stale"
    case .unavailable: return "Unavailable"
    }
  }

  private var freshnessSymbol: String {
    switch store.advisorySnapshot.freshness {
    case .fresh:       return "checkmark.circle"
    case .stale:       return "clock.badge.exclamationmark"
    case .unavailable: return "circle.dashed"
    }
  }

  private func color(for severity: AdvisorySeverity) -> Color {
    switch severity {
    case .critical: return .red
    case .high:     return .orange
    case .moderate: return .yellow
    case .low:      return .secondary
    }
  }

  private static let dateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
  }()
}
