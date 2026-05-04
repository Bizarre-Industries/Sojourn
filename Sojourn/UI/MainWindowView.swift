// Sojourn — MainWindowView (v0.2)
//
// NavigationSplitView shell with typed `Pane` enum. macOS 26 Tahoe
// applies the Liquid Glass material to the split-view chrome
// automatically; no manual `.ultraThinMaterial` overlays. Aurora
// wallpaper dropped per v0.2-pivot-plan §3.
//
// Refs: docs/process/plans/v0.2-plan.md step 3;
//       lessons.md "Real Liquid Glass needs `glassEffect`,
//                   not `.ultraThinMaterial`".

import SwiftUI

/// Top-level navigation surface. v0.2 fixes 10 first-class panes;
/// power-surface entries from v0.1 cosmetic-preview no longer appear
/// in the sidebar but remain reachable via Settings → Diagnostics or
/// the Jobs pane (step 4 wires the routing).
internal enum Pane: String, Hashable, CaseIterable, Identifiable {
  case dashboard
  case packages
  case containers
  case generations
  case macosFeatures
  case preferences
  case sync
  case machines
  case advisories
  case jobs
  case settings

  internal var id: String { rawValue }

  internal var label: String {
    switch self {
    case .dashboard:     return "Dashboard"
    case .packages:      return "Packages"
    case .containers:    return "Containers"
    case .generations:   return "Generations"
    case .macosFeatures: return "macOS Features"
    case .preferences:   return "Preferences"
    case .sync:          return "Sync"
    case .machines:      return "Machines"
    case .advisories:    return "Advisories"
    case .jobs:          return "Jobs"
    case .settings:      return "Settings"
    }
  }

  internal var icon: String {
    switch self {
    case .dashboard:     return "rocket"
    case .packages:      return "shippingbox"
    case .containers:    return "cube.box"
    case .generations:   return "clock.arrow.circlepath"
    case .macosFeatures: return "switch.2"
    case .preferences:   return "slider.horizontal.3"
    case .sync:          return "arrow.triangle.2.circlepath"
    case .machines:      return "laptopcomputer.and.iphone"
    case .advisories:    return "exclamationmark.shield"
    case .jobs:          return "terminal"
    case .settings:      return "gear"
    }
  }
}

internal struct MainWindowView: View {
  @Environment(AppStore.self) private var store
  @State private var selection: Pane = .dashboard

  var body: some View {
    NavigationSplitView {
      List(Pane.allCases, selection: $selection) { pane in
        HStack(spacing: 8) {
          Label(pane.label, systemImage: pane.icon)
          if pane == .sync, let count = syncBadgeCount, count > 0 {
            // ADR-0026 + council 2026-05-04 devil-advocate amendment:
            // count + glyph (not color-only) so colorblind users get
            // the signal too.
            Label("\(count)", systemImage: "exclamationmark.circle.fill")
              .labelStyle(.titleAndIcon)
              .font(.caption)
              .foregroundStyle(.orange)
              .accessibilityLabel("\(count) inbound commits pending")
          }
        }
        .tag(pane)
        .accessibilityIdentifier("sidebar.\(pane.rawValue)")
      }
      .navigationTitle("Sojourn")
      .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 320)
    } detail: {
      detail(for: selection)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(selection.label)
    }
    .frame(minWidth: 1180, idealWidth: 1280, minHeight: 720, idealHeight: 800)
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

  /// Count of inbound commits when ConflictResolver knows about
  /// pending or blocked work. nil otherwise. ADR-0026 amendment
  /// "cross-pane conflict-pending visibility" + council 2026-05-04
  /// devil-advocate amendment (count over dot for fleet visibility).
  private var syncBadgeCount: Int? {
    guard let resolver = store.conflictResolver else { return nil }
    switch resolver.state {
    case .conflictPending(let commits): return commits.count
    case .blockedFromPush, .failed:     return resolver.pendingCommits.count > 0 ? resolver.pendingCommits.count : 1
    case .clean, .detecting, .resolving, .resolved: return nil
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
    case .dashboard:     OverviewPane()
    case .packages:      PackagesPane()
    case .containers:    ContainersPane()
    case .generations:   GenerationsPane()
    case .macosFeatures: MacOSFeaturesPane()
    case .preferences:   PreferencesPane()
    case .sync:          SyncPane()
    case .machines:      MachinesPane()
    case .advisories:    AdvisoriesPane()
    case .jobs:          JobInspectorPane()
    case .settings:      SettingsPaneEmbedded()
    }
  }
}
