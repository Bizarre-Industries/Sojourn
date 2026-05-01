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
    ZStack {
      // Deepest layer: aurora wallpaper that the glass refracts.
      GlassWallpaper()

      // Floating tiles (Tahoe-spec). Sidebar inset from titlebar; content
      // is its own glass tile next to it. Per liquid-glass.css:131-198 +
      // chat 1's "doesn't even use Liquid Glass" rewrite.
      HStack(spacing: 8) {
        LiquidGlassSidebar(
          selection: $selection,
          machineName: machineDisplayName,
          machineRole: "ACTIVE WRITER",
          machineActivity: "2h AGO",
          machineSha: "a3f9c2e"
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.50), radius: 20, x: 0, y: 14)

        VStack(spacing: 0) {
          SojournToolbar(title: titleFor(selection), eyebrow: "BIZARRE / SOJOURN")
          Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 0.5)
          detail(for: selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.50), radius: 20, x: 0, y: 14)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .padding(8)
    }
    .frame(minWidth: 1024, minHeight: 640)
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
    case "overview":            OverviewPane()
    case "packages":            PackagesPane()
    case "dotfiles":            DotfilesPane()
    case "preferences":         PreferencesPane()
    case "machines":            MachinesPane()
    case "history":             HistoryPane()
    case "conflicts":           ConflictsPane()
    case "onboard":             OnboardPane()
    case "secrets":             SecretsPane()
    case "cleanup":             CleanupPane()
    case "diagnostics":         DiagnosticsPane()
    case "settings":            SettingsPaneEmbedded()
    case "jobs":                JobInspectorPane()
    case "schedule":            ScheduleInspectorPane()
    case "age":                 AgeKeysPane()
    case "chezmoi-templates":   ChezmoiTemplatesPane()
    case "gitleaks-rules":      GitleaksRulesPane()
    case "authorization":       AuthorizationPane()
    case "manager-detail":      ManagerDetailPane()
    case "backups":             BackupsPane()
    case "defaults-discover":   DefaultsDiscoverPane()
    case "repo-setup":          RepoSetupPane()
    default:                    OverviewPane()
    }
  }
}
