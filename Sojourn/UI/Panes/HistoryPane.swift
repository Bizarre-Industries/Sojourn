// Sojourn — HistoryPane

import SwiftUI

struct HistoryPane: View {
  @Environment(AppStore.self) private var store

  private struct TimelineEntry: Identifiable {
    let id = UUID()
    let sha: String
    let when: String
    let kind: String
    let kindBadge: BzrBadgeKind
    let message: String
    let machine: String
    let stats: String?
    let snapshot: String?
    let nodeColor: NodeColor

    enum NodeColor { case lime, warn, mute }
  }

  // Demo data; replaced by store.history projection in Phase B.
  private var demoEntries: [TimelineEntry] {
    [
      .init(sha: "a3f9c2e", when: "2h ago", kind: "PUSH", kindBadge: .lime, message: "brew bundle install ripgrep + fd + eza", machine: "work-mbp", stats: "+24 −2", snapshot: nil, nodeColor: .lime),
      .init(sha: "7b1de44", when: "1d ago", kind: "PULL", kindBadge: .mute, message: "sync from personal-mini · 6 changes", machine: "work-mbp", stats: "+183 −47", snapshot: "snap_2026-04-27T08-12.tgz", nodeColor: .lime),
      .init(sha: "c08fa12", when: "2d ago", kind: "PUSH", kindBadge: .mute, message: "iterm2 prefs · zshrc edit", machine: "personal-mini", stats: "+12 −4", snapshot: nil, nodeColor: .mute),
      .init(sha: "ee31a09", when: "3d ago", kind: "APPLY", kindBadge: .mute, message: "chezmoi apply --force after pull", machine: "work-mbp", stats: "4 files", snapshot: "snap_2026-04-25T19-02.tgz", nodeColor: .mute),
      .init(sha: "114b8f0", when: "4d ago", kind: "CLEAN", kindBadge: .mute, message: "trashed 8 dotfile orphans", machine: "work-mbp", stats: "−2.4GB", snapshot: "deletions.db row#341", nodeColor: .mute),
      .init(sha: "82de019", when: "5d ago", kind: "CONFLICT", kindBadge: .tierC, message: "resolved · keep local .zshrc", machine: "work-mbp", stats: nil, snapshot: nil, nodeColor: .warn),
      .init(sha: "44ab821", when: "6d ago", kind: "PUSH", kindBadge: .mute, message: "cargo update + Raycast prefs", machine: "personal-mini", stats: "+9 −9", snapshot: nil, nodeColor: .mute)
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "WORK-MBP ↔ origin · git@github.com:you/my-mac.git")
          .padding(.top, 8)
        Text("47 COMMITS · 12 SNAPSHOTS")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Pre-op tarballs retained 30 days. Every push is gitleaks-scanned. Every pull writes a snapshot before touching the working tree. Roll back without leaving the app.")
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
      VStack(alignment: .leading, spacing: 0) {
        ForEach(demoEntries) { entry in
          timelineRow(entry)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
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
  private func timelineRow(_ entry: TimelineEntry) -> some View {
    HStack(alignment: .top, spacing: 14) {
      timelineNode(entry.nodeColor)
        .padding(.top, 4)
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Text(entry.sha)
            .font(.bzrMono(size: 11, weight: .semibold))
            .foregroundStyle(Color.bzrLime)
          BzrBadge(text: entry.kind, kind: entry.kindBadge)
          Text(entry.message)
            .font(.bzrBody(size: 12, weight: .semibold))
            .foregroundStyle(Color.txtPrimary)
          Spacer()
          Text(entry.when)
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
        }
        HStack(spacing: 6) {
          Image(systemName: "laptopcomputer")
            .font(.system(size: 9))
            .foregroundStyle(Color.txtTertiary)
          Text(entry.machine)
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
          if let stats = entry.stats {
            Text("·")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtQuaternary)
            Text(stats)
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtTertiary)
          }
          if let snapshot = entry.snapshot {
            Text("·")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtQuaternary)
            Image(systemName: "archivebox")
              .font(.system(size: 9))
              .foregroundStyle(Color.bzrLime)
            Text(snapshot)
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.bzrLime)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          Spacer()
          Button {} label: {
            Text("↶ Roll back")
              .font(.bzrMono(size: 10))
          }
          .buttonStyle(GlassGhostButtonStyle())
        }
      }
    }
    .padding(.vertical, 10)
  }

  @ViewBuilder
  private func timelineNode(_ kind: TimelineEntry.NodeColor) -> some View {
    let color: Color = {
      switch kind {
      case .lime: return .bzrLime
      case .warn: return .bzrWarn
      case .mute: return .bzrVoid3
      }
    }()
    Circle()
      .fill(color)
      .frame(width: 13, height: 13)
      .overlay(
        Circle().stroke(color, lineWidth: 1)
      )
      .shadow(color: kind == .lime ? color : Color.clear, radius: 4)
  }
}
