// Sojourn — SyncPane
//
// Consolidated multi-tab surface hosting the four sync sub-panes
// (push/pull history, conflicts, onboarding, machine writer-lock
// status). Extracted from V02Stubs.swift in v0.3 stage 5 per CLAUDE.md
// "File names match primary declaration" + ADR-0026 §"Consequences"
// (V02Stubs.swift wrapper removed).
//
// Refs: ADR-0012 cooperative writer lock — pull resolves any conflict
//       before push is allowed;
//       ADR-0026 multi-machine conflict UX.

import SwiftUI

internal struct SyncPane: View {
  private enum Tab: String, Hashable, CaseIterable, Identifiable {
    case history
    case conflicts
    case onboard
    case machines

    var id: String { rawValue }

    var label: String {
      switch self {
      case .history:   return "History"
      case .conflicts: return "Conflicts"
      case .onboard:   return "Onboard"
      case .machines:  return "Machines"
      }
    }

    var icon: String {
      switch self {
      case .history:   return "clock"
      case .conflicts: return "exclamationmark.triangle"
      case .onboard:   return "play.circle"
      case .machines:  return "laptopcomputer.and.iphone"
      }
    }
  }

  @Environment(AppStore.self) private var store
  @State private var tab: Tab = .history
  @State private var didAutoRoute = false

  var body: some View {
    VStack(spacing: 0) {
      Picker("", selection: $tab) {
        ForEach(Tab.allCases) { t in
          Label(t.label, systemImage: t.icon).tag(t)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(.horizontal, 24)
      .padding(.top, 16)
      .padding(.bottom, 8)

      Divider()

      Group {
        switch tab {
        case .history:   HistoryPane()
        case .conflicts: ConflictsPane()
        case .onboard:   OnboardPane()
        case .machines:  MachinesPane()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityIdentifier("pane.sync")
    .onAppear {
      // ADR-0026: first-appearance auto-routes to Conflicts tab when
      // the resolver knows about pending inbound work, so the user
      // lands on the resolution surface, not History. Guarded by
      // didAutoRoute so a manual return to History sticks (council
      // 2026-05-04 ux-critic condition).
      if !didAutoRoute, case .conflictPending = store.conflictResolver?.state {
        tab = .conflicts
        didAutoRoute = true
      }
    }
  }
}
