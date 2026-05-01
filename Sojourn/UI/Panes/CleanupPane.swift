// Sojourn — CleanupPane

import SwiftUI

struct CleanupPane: View {
  @Environment(AppStore.self) private var store
  @State private var scanning = false

  private struct OrphanRow: Identifiable {
    let id = UUID()
    let selected: Bool
    let path: String
    let size: String
    let owner: String
    let klass: String
    let klassKind: BzrBadgeKind
    let lastTouched: String
    let action: String
  }

  // Demo rows — replaced by store.orphans projection in Phase B.
  private var demoRows: [OrphanRow] {
    [
      .init(selected: true, path: "~/.rbenv/", size: "412 MB", owner: "rbenv (brew · uninstalled 2025-12-04)", klass: "SAFE", klassKind: .success, lastTouched: "142 days", action: "TRASH"),
      .init(selected: true, path: "~/.nvm/", size: "1.1 GB", owner: "nvm (curl · uninstalled)", klass: "SAFE", klassKind: .success, lastTouched: "98 days", action: "TRASH"),
      .init(selected: true, path: "~/.config/old-fish/", size: "8.4 MB", owner: "fish shell (not in brew · zsh active)", klass: "REVIEW", klassKind: .tierC, lastTouched: "211 days", action: "TRASH"),
      .init(selected: true, path: "~/Library/Application Support/Atom/", size: "887 MB", owner: "com.github.atom (no bundle ID found)", klass: "REVIEW", klassKind: .tierC, lastTouched: "3 years", action: "TRASH"),
      .init(selected: false, path: "~/.docker/", size: "3.2 MB", owner: "Docker (cask · still installed)", klass: "KEEP", klassKind: .mute, lastTouched: "2 days", action: "—"),
      .init(selected: false, path: "~/.zsh_sessions/", size: "21 MB", owner: "zsh (system · active)", klass: "RISKY", klassKind: .tierE, lastTouched: "2 hours", action: "—"),
      .init(selected: false, path: "~/Library/LaunchAgents/com.heroku.cli.plist", size: "2 KB", owner: "heroku (brew · uninstalled)", klass: "RISKY", klassKind: .tierE, lastTouched: "62 days", action: "prompt")
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "HYGIENE / DOTFILE ORPHANS / RECONCILED AGAINST TOOL INVENTORY")
          .padding(.top, 8)
        Text("12 ORPHANS · 2.4GB")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Reconciled against brew list, pipx list, $PATH probes, and data/dotfile_owners.toml. Shell history grep, last-used xattrs, and parent-dir mtime gate the call. Never auto-delete. Always Trash.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        BzrCallout(
          title: "APFS atime is not trustworthy",
          kind: .danger,
          bodyText: "Default mount is non-strict atime. Quick Look ticks it. Spotlight ticks it. We use it as a tiebreaker only. Read the docs if you care."
        )

        HStack {
          Button {
            Task {
              scanning = true
              await store.rescanOrphans()
              scanning = false
            }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: scanning ? "arrow.clockwise" : "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
              Text(scanning ? "Scanning…" : "Scan ~/Library")
            }
          }
          .buttonStyle(GlassCapsuleButtonStyle())
          .disabled(scanning)
          .accessibilityIdentifier("pane.cleanup.scan")

          Spacer()

          Button {} label: {
            HStack(spacing: 6) {
              Image(systemName: "trash")
                .font(.system(size: 11, weight: .semibold))
              Text("Move 4 to Trash")
            }
          }
          .buttonStyle(GlassDangerButtonStyle())
        }

        Text("Orphan candidates")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 4)

        orphanTable

        Text("↻ DELETIONS LOGGED TO ~/Library/Application Support/Sojourn/deletions.db · 10 MOST RECENT UNDOABLE")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.cleanup")
  }

  private var orphanTable: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 0) {
        orphanHeader("", width: 28)
        orphanHeader("Path", width: 240)
        orphanHeader("Size", width: 80)
        orphanHeader("Owner (missing)", width: 240)
        orphanHeader("Class", width: 80)
        orphanHeader("Last touched", width: 100)
        orphanHeader("Action", width: 80)
      }
      .background(Color.white.opacity(0.02))
      .overlay(
        Rectangle().fill(Color.hairline).frame(height: 0.5),
        alignment: .bottom
      )

      ForEach(demoRows) { row in
        HStack(spacing: 0) {
          // Checkbox
          HStack {
            Image(systemName: row.selected ? "checkmark.square.fill" : "square")
              .font(.system(size: 12))
              .foregroundStyle(row.selected ? Color.bzrLime : Color.txtTertiary)
            Spacer()
          }
          .frame(width: 28).padding(.horizontal, 8).padding(.vertical, 7)

          orphanCell(row.path, width: 240, color: .txtPrimary, weight: .semibold)
          orphanCell(row.size, width: 80, color: .txtTertiary)
          orphanCell(row.owner, width: 240, color: .txtTertiary)
          HStack { BzrBadge(text: row.klass, kind: row.klassKind); Spacer() }
            .frame(width: 80).padding(.horizontal, 12).padding(.vertical, 7)
          orphanCell(row.lastTouched, width: 100, color: .txtTertiary)
          HStack {
            if row.action == "—" {
              Text("—").font(.bzrMono(size: 10)).foregroundStyle(Color.txtTertiary)
            } else if row.action == "prompt" {
              Text("prompt").font(.bzrMono(size: 10)).foregroundStyle(Color.txtTertiary)
            } else {
              BzrBadge(text: row.action, kind: .mute)
            }
            Spacer()
          }
          .frame(width: 80).padding(.horizontal, 12).padding(.vertical, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
          Rectangle().fill(Color.hairlineInner).frame(height: 0.5),
          alignment: .bottom
        )
      }
    }
    .background(Color.black.opacity(0.20))
    .clipShape(RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
        .stroke(Color.hairline, lineWidth: 0.5)
    )
  }

  @ViewBuilder
  private func orphanHeader(_ text: String, width: CGFloat) -> some View {
    Text(text)
      .font(.bzrMono(size: 9, weight: .semibold))
      .tracking(1.6)
      .textCase(.uppercase)
      .foregroundStyle(Color.txtTertiary)
      .frame(width: width, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
  }

  @ViewBuilder
  private func orphanCell(_ text: String, width: CGFloat, color: Color, weight: Font.Weight = .medium) -> some View {
    Text(text)
      .font(.bzrMono(size: 11, weight: weight))
      .foregroundStyle(color)
      .frame(width: width, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .lineLimit(1)
      .truncationMode(.middle)
  }

  private func badgeKind(for c: OrphanCandidate.Category) -> BzrBadgeKind {
    switch c {
    case .safe:   return .success
    case .review: return .warn
    case .risky:  return .danger
    }
  }
}
