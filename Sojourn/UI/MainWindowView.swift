// Sojourn — MainWindowView
//
// Primary window. Carry-first 12-entry sidebar (`SojournSidebarMenu`),
// Liquid Glass shell over the wallpaper, glass toolbar with Push/Pull.
// Pane content gets richer in Stage 3; Stage 2 establishes the chrome.

import SwiftUI

struct MainWindowView: View {
  @Environment(AppStore.self) private var store
  @State private var selection: String = "overview"

  var body: some View {
    HStack(spacing: 0) {
      LiquidGlassSidebar(
        selection: $selection,
        machineName: machineDisplayName,
        machineRole: "ACTIVE WRITER",
        machineActivity: "2h AGO",
        machineSha: "a3f9c2e"
      )

      VStack(spacing: 0) {
        SojournToolbar(title: titleFor(selection), eyebrow: "BIZARRE / SOJOURN")

        Divider()
          .background(Color.hairline)

        ZStack {
          Color.glassContent
          detail(for: selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minWidth: 1024, minHeight: 640)
    .background(
      ZStack {
        GlassWallpaper()
        Color.glassWindow
      }
      .ignoresSafeArea()
    )
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

  private var machineDisplayName: String {
    Host.current().localizedName ?? "this-mac"
  }

  private func titleFor(_ id: String) -> String {
    SojournSidebarMenu.entries.first { $0.id == id }?.label ?? "Sojourn"
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
  private func detail(for id: String) -> some View {
    switch id {
    case "overview":    OverviewPane()
    case "packages":    PackagesPane()
    case "dotfiles":    DotfilesPane()
    case "preferences": PreferencesPane()
    case "machines":    MachinesPane()
    case "history":     HistoryPane()
    case "conflicts":   ConflictsPane()
    case "onboard":     OnboardPane()
    case "secrets":     SecretsPane()
    case "cleanup":     CleanupPane()
    case "diagnostics": DiagnosticsPane()
    case "settings":    SettingsPaneEmbedded()
    default:            OverviewPane()
    }
  }
}
