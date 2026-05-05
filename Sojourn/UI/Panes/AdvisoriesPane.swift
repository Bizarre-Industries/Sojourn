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

      Divider()
      cacheFooter
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
      .accessibilityIdentifier("advisories.refresh")
      .accessibilityLabel("Refresh advisory cache")
      .accessibilityHint("Reloads the cached Homebrew vulnerability snapshot.")
    }
  }

  private func advisoryRow(_ advisory: AdvisoryReference) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(
        systemName: advisory.triggersBypass ? "exclamationmark.octagon" : "exclamationmark.triangle"
      )
      .foregroundStyle(color(for: advisory.severity))
      .frame(width: 22)
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 5) {
        Text(advisory.id)
          .font(.callout.weight(.semibold))
        Text(advisory.summary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        Text(advisoryPackageSummary(advisory))
          .font(.caption2)
          .foregroundStyle(.tertiary)
          .lineLimit(2)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        "\(advisory.id). \(advisory.summary). \(advisoryPackageSummary(advisory))."
      )
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        VStack(alignment: .trailing, spacing: 4) {
          Text(advisory.severity.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color(for: advisory.severity))
          Text(advisory.feed.rawValue.uppercased())
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
          Text(advisory.triggersBypass ? "Bypasses cooldown" : "Cooldown applies")
            .font(.caption2)
            .foregroundStyle(advisory.triggersBypass ? Color.orange : Color.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(advisory.severity.rawValue.capitalized). \(advisory.feed.rawValue.uppercased()). \(advisory.triggersBypass ? "Bypasses cooldown." : "Cooldown applies.")"
        )

        if let url = advisory.referenceURL {
          Link("Reference", destination: url)
            .font(.caption2)
            .accessibilityLabel("Open reference for \(advisory.id)")
        }
      }
    }
    .padding(.vertical, 5)
    .accessibilityElement(children: .contain)
  }

  private var cacheFooter: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 3) {
        Text(snapshotDates)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(cacheKeyLabel)
          .font(.caption.monospaced())
          .foregroundStyle(.tertiary)
      }
      Spacer()
      Text("\(store.advisorySnapshot.advisories.count) advisories")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityIdentifier("advisories.cache-metadata")
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
      return
        "No cached advisory snapshot. Configure Homebrew vulnerability data with consent, then refresh this pane."
    }
  }

  private var snapshotDates: String {
    let success =
      store.advisorySnapshot.lastSuccessAt
      .map { "Last success \(Self.dateFormatter.localizedString(for: $0, relativeTo: Date()))." }
      ?? "No successful scan recorded."
    let attempt =
      store.advisorySnapshot.lastAttemptAt
      .map { "Last attempt \(Self.dateFormatter.localizedString(for: $0, relativeTo: Date()))." }
      ?? "No scan attempt recorded."
    return "\(success) \(attempt)"
  }

  private var cacheKeyLabel: String {
    guard let key = store.advisorySnapshot.cacheKeySHA256 else {
      return "Cache key unavailable"
    }
    return "Cache key \(String(key.prefix(12)))"
  }

  private func advisoryPackageSummary(_ advisory: AdvisoryReference) -> String {
    let packages =
      advisory.affectedPackages.isEmpty
      ? "No affected packages recorded"
      : advisory.affectedPackages
        .map(\.canonicalString)
        .prefix(3)
        .joined(separator: ", ")
    let fixed =
      advisory.fixedVersions.isEmpty
      ? "No fixed versions recorded"
      : "Fixed \(advisory.fixedVersions.prefix(3).joined(separator: ", "))"
    return
      "\(packages). \(fixed). Modified \(Self.dateFormatter.localizedString(for: advisory.modifiedAt, relativeTo: Date()))."
  }

  private var freshnessLabel: String {
    switch store.advisorySnapshot.freshness {
    case .fresh: return "Fresh"
    case .stale: return "Stale"
    case .unavailable: return "Unavailable"
    }
  }

  private var freshnessSymbol: String {
    switch store.advisorySnapshot.freshness {
    case .fresh: return "checkmark.circle"
    case .stale: return "clock.badge.exclamationmark"
    case .unavailable: return "circle.dashed"
    }
  }

  private func color(for severity: AdvisorySeverity) -> Color {
    switch severity {
    case .critical: return .red
    case .high: return .orange
    case .moderate: return .yellow
    case .low: return .secondary
    }
  }

  private static let dateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
  }()
}
