// Sojourn — MainWindowView
//
// Primary window. NavigationSplitView with the sidebar listing panes and
// a pane-level detail column. See docs/ARCHITECTURE.md §11.

import SwiftUI

struct MainWindowView: View {
  @Environment(AppStore.self) private var store
  @State private var selection: Pane? = .packages

  enum Pane: String, Hashable, CaseIterable, Identifiable {
    case packages, dotfiles, preferences, history, machines, cleanup
    var id: String { rawValue }

    var title: String {
      switch self {
      case .packages: return "Packages"
      case .dotfiles: return "Dotfiles"
      case .preferences: return "Preferences"
      case .history: return "History"
      case .machines: return "Machines"
      case .cleanup: return "Cleanup"
      }
    }

    var systemImage: String {
      switch self {
      case .packages: return "shippingbox"
      case .dotfiles: return "doc.text"
      case .preferences: return "slider.horizontal.3"
      case .history: return "clock.arrow.circlepath"
      case .machines: return "laptopcomputer.and.iphone"
      case .cleanup: return "trash"
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      Sidebar(selection: $selection)
        .navigationTitle("Sojourn")
        .frame(minWidth: 200)
    } detail: {
      VStack(spacing: 0) {
        PushPullBar()
        Divider()
        detail(for: selection ?? .packages)
      }
      .frame(minWidth: 600, minHeight: 400)
    }
    .sheet(isPresented: bootstrapSheetPresented) {
      BootstrapView(
        state: store.bootstrap.state,
        onConsent: {
          Task { await store.bootstrap.proceed() }
        },
        onRetry: {
          Task { await store.bootstrap.probe() }
        }
      )
    }
  }

  private var bootstrapSheetPresented: Binding<Bool> {
    Binding(
      get: {
        switch store.bootstrap.state {
        case .ready, .unknown: return false
        default: return true
        }
      },
      set: { _ in }
    )
  }

  @ViewBuilder
  private func detail(for pane: Pane) -> some View {
    switch pane {
    case .packages: PackagesPane()
    case .dotfiles: DotfilesPane()
    case .preferences: PreferencesPane()
    case .history: HistoryPane()
    case .machines: MachinesPane()
    case .cleanup: CleanupPane()
    }
  }
}

struct Sidebar: View {
  @Binding var selection: MainWindowView.Pane?

  var body: some View {
    List(selection: $selection) {
      ForEach(MainWindowView.Pane.allCases) { pane in
        Label(pane.title, systemImage: pane.systemImage)
          .tag(Optional(pane))
          .accessibilityIdentifier("sidebar.\(pane.rawValue)")
      }
    }
    .listStyle(.sidebar)
  }
}
