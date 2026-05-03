// Sojourn — v0.2 pane shell
//
// SyncPane is the consolidated multi-tab surface that hosts the four
// pre-existing sync sub-panes (push/pull history, conflicts, onboarding,
// machine writer-lock status). The earlier stub `StubView` is gone now
// that all v0.2 panes are real.
//
// Refs: docs/process/plans/v0.2-plan.md;
//       ADR-0012 (cooperative writer lock — pull resolves any conflict
//                 before push is allowed).

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

  @State private var tab: Tab = .history

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
  }
}
