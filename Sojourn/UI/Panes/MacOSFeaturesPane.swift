// Sojourn — MacOSFeaturesPane

import SwiftUI

struct MacOSFeaturesPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header

      if store.macOSFeatureRows.isEmpty {
        ProgressView("Reading feature state...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(store.macOSFeatureRows) { row in
          featureRow(row)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
      }
    }
    .padding(24)
    .background(Color(nsColor: .windowBackgroundColor))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("pane.macos-features")
    .task {
      await store.refreshMacOSFeatureSnapshot()
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text("macOS Features")
          .font(.title2.weight(.semibold))
        Text("Read-only snapshot of Sojourn-managed system preferences.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        Task { await store.refreshMacOSFeatureSnapshot(force: true) }
      } label: {
        Label("Refresh", systemImage: "arrow.clockwise")
          .accessibilityIdentifier("macosFeatures.refresh")
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("macosFeatures.refresh")
      .accessibilityLabel("Refresh macOS feature state")
      .accessibilityHint("Reloads the read-only system preference snapshot.")
    }
  }

  private func featureRow(_ row: AppStore.MacOSFeatureStatusRow) -> some View {
    HStack(spacing: 12) {
      Image(systemName: row.symbol)
        .foregroundStyle(.secondary)
        .frame(width: 22)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(row.title)
          .font(.callout.weight(.semibold))
        Text(row.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text(row.value)
        .font(.callout)
        .foregroundStyle(row.value == "Unknown" ? .secondary : .primary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .padding(.vertical, 5)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(row.title). \(row.value). \(row.detail).")
  }
}
