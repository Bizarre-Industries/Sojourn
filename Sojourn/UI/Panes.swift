// Sojourn — Panes
//
// Six detail panes that hang off the main window's NavigationSplitView.
// Each pane reads the @Environment(AppStore.self) for live state. See
// docs/ARCHITECTURE.md §11.

import SwiftUI

struct PackagesPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    if store.managers.isEmpty {
      ContentUnavailableView(
        "No package managers detected",
        systemImage: "shippingbox",
        description: Text("Run Bootstrap to install mpm + brew.")
      )
      .accessibilityIdentifier("pane.packages.empty")
    } else {
      List {
        ForEach(Array(store.managers.keys.sorted()), id: \.self) { manager in
          if let snap = store.managers[manager] {
            Section {
              ForEach(snap.packages) { pkg in
                HStack {
                  VStack(alignment: .leading) {
                    Text(pkg.name ?? pkg.id).font(.body)
                    Text(pkg.installedVersion ?? "—")
                      .font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Text(manager).font(.caption.monospaced())
                }
              }
            } header: {
              Text(snap.name).font(.headline)
            }
          }
        }
      }
      .accessibilityIdentifier("pane.packages.list")
    }
  }
}

struct DotfilesPane: View {
  var body: some View {
    ContentUnavailableView(
      "Dotfiles",
      systemImage: "doc.text",
      description: Text("Run a pull to populate the chezmoi-managed list.")
    )
    .accessibilityIdentifier("pane.dotfiles")
  }
}

struct PreferencesPane: View {
  var body: some View {
    ContentUnavailableView(
      "App Preferences",
      systemImage: "slider.horizontal.3",
      description: Text("Per-app plist sync list will appear here after a sync.")
    )
    .accessibilityIdentifier("pane.preferences")
  }
}

struct HistoryPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    if store.history.isEmpty {
      ContentUnavailableView(
        "No history yet",
        systemImage: "clock.arrow.circlepath",
        description: Text("Every sync, install, and cleanup lands here.")
      )
      .accessibilityIdentifier("pane.history.empty")
    } else {
      List(store.history.reversed()) { entry in
        VStack(alignment: .leading) {
          HStack {
            Text(entry.kind.rawValue).font(.caption.monospaced())
            Spacer()
            Text(entry.timestamp, style: .relative)
              .font(.caption).foregroundStyle(.secondary)
          }
          Text(entry.description).font(.body)
        }
      }
      .accessibilityIdentifier("pane.history.list")
    }
  }
}

struct MachinesPane: View {
  var body: some View {
    ContentUnavailableView(
      "Machines",
      systemImage: "laptopcomputer.and.iphone",
      description: Text("Per-Mac identity + overrides will appear here.")
    )
    .accessibilityIdentifier("pane.machines")
  }
}

struct CleanupPane: View {
  @State private var candidates: [OrphanCandidate] = []

  var body: some View {
    VStack(spacing: 0) {
      if candidates.isEmpty {
        ContentUnavailableView(
          "Cleanup",
          systemImage: "trash",
          description: Text("Press Scan to find orphan files in ~/Library.")
        )
      } else {
        List(candidates) { candidate in
          HStack {
            VStack(alignment: .leading) {
              Text(candidate.path.lastPathComponent).font(.body)
              Text(candidate.reason).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(candidate.category.rawValue)
              .font(.caption.monospaced())
              .padding(.horizontal, 6).padding(.vertical, 2)
              .background(color(for: candidate.category).opacity(0.15))
              .clipShape(Capsule())
          }
        }
      }
      Divider()
      HStack {
        Button("Scan") { candidates = [] }
        Spacer()
      }
      .padding()
    }
    .accessibilityIdentifier("pane.cleanup")
  }

  private func color(for c: OrphanCandidate.Category) -> Color {
    switch c {
    case .safe: return .green
    case .review: return .orange
    case .risky: return .red
    }
  }
}
