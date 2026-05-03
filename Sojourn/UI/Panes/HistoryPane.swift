// Sojourn — HistoryPane

import SwiftUI

struct HistoryPane: View {
  @Environment(AppStore.self) private var store

  private static let relativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f
  }()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: store.settings.remoteRepoURL ?? "Sync remote not configured — see Settings → Sync")
          .padding(.top, 8)
        Text("\(store.history.count) ENTRIES")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Pre-op tarballs retained 30 days. Every push is gitleaks-scanned. Every pull writes a snapshot before touching the working tree.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        timelineCard
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.history")
  }

  private var timelineCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("TIMELINE · HEAD ← origin/main")
          .font(.bzrTinyEyebrow)
          .tracking(1.6)
          .textCase(.uppercase)
          .foregroundStyle(Color.txtTertiary)
        Spacer()
        Text("RETENTION · 30D")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .overlay(
        Rectangle().fill(Color.hairline).frame(height: 0.5),
        alignment: .bottom
      )

      // Timeline rail.
      if store.history.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("No history yet")
            .font(.bzrBody(size: 13, weight: .semibold))
            .foregroundStyle(Color.txtPrimary)
          Text("History entries are written to ~/Library/Application Support/Sojourn/config/history.sqlite each time Sojourn pushes, pulls, applies, or scans. Run a Pull or Push from the menubar to populate this list.")
            .font(.bzrBody(size: 12))
            .foregroundStyle(Color.txtSecondary)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(store.history) { entry in
            historyRow(entry)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )
    )
  }

  @ViewBuilder
  private func historyRow(_ entry: HistoryEntry) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Circle()
        .fill(Color.bzrLime)
        .frame(width: 13, height: 13)
        .padding(.top, 4)
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          BzrBadge(text: entry.kind.rawValue.uppercased(), kind: .mute)
          Text(entry.description)
            .font(.bzrBody(size: 12, weight: .semibold))
            .foregroundStyle(Color.txtPrimary)
          Spacer()
          Text(Self.relativeFormatter.localizedString(for: entry.timestamp, relativeTo: Date()))
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
        }
        if let snap = entry.snapshotPath {
          HStack(spacing: 6) {
            Image(systemName: "archivebox")
              .font(.system(size: 9))
              .foregroundStyle(Color.bzrLimeText)
            Text(snap)
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtTertiary)
              .lineLimit(1)
              .truncationMode(.middle)
            Spacer()
          }
        }
      }
    }
    .padding(.vertical, 10)
  }
}
