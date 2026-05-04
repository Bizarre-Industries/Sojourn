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

      syncStatusBanner

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
      if !didAutoRoute, case .awaitingPullDecision = store.sync?.phase {
        tab = .conflicts
        didAutoRoute = true
      }
    }
  }

  @ViewBuilder
  private var syncStatusBanner: some View {
    switch store.sync?.phase {
    case .failed(let reason):
      statusBanner(
        symbol: "xmark.octagon",
        title: "Sync needs attention",
        message: "\(reason) Fix the cause, then retry Pull and Apply or Push After Scan from the toolbar.",
        actionTitle: "Dismiss failure",
        actionHint: "Clears this message only; it does not retry sync or undo staged files.",
        action: { store.sync?.reset() }
      )
      Divider()
    case .awaitingPullDecision(let commits):
      statusBanner(
        symbol: "exclamationmark.triangle",
        title: "\(commits.count) inbound commit(s)",
        message: "Review Conflicts and choose rebase, merge, or abort before pushing.",
        actionTitle: "Review Conflicts",
        action: { tab = .conflicts }
      )
      Divider()
    case .idle, .pulling, .resolvingConflicts, .scanningSecrets, .pushing, .done, nil:
      EmptyView()
    }
  }

  private func statusBanner(
    symbol: String,
    title: String,
    message: String,
    actionTitle: String,
    actionHint: String? = nil,
    action: @escaping () -> Void
  ) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .foregroundStyle(Color.orange)
        .frame(width: 22)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.callout.weight(.semibold))
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(title). \(message)")
      Spacer()
      Button(actionTitle, action: action)
        .accessibilityHint(actionHint ?? "")
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 12)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}
