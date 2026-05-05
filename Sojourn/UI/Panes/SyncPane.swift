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
  @State private var isApplyReviewConfirmationPresented = false

  var body: some View {
    VStack(spacing: 0) {
      Picker("", selection: $tab) {
        ForEach(Tab.allCases) { t in
          Label(t.label, systemImage: t.icon).tag(t)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .accessibilityLabel("Sync sections")
      .accessibilityIdentifier("sync.tabs")
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
    .confirmationDialog(
      String(localized: "Apply listed pulled changes?"),
      isPresented: $isApplyReviewConfirmationPresented,
      titleVisibility: .visible
    ) {
      Button(String(localized: "Apply Listed Changes")) {
        Task { await store.applyReviewedPull() }
      }
      Button(String(localized: "Cancel"), role: .cancel) {}
    } message: {
      Text(String(localized: "Sojourn will create a generation, run chezmoi apply, and run brew bundle install for the already-pulled data repo state. Cancel leaves the repo pulled but not applied."))
    }
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
      if !didAutoRoute, case .awaitingPullApplyReview = store.sync?.phase {
        tab = .history
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
    case .awaitingPullApplyReview(let review):
      pullApplyReviewBanner(review)
      Divider()
    case .applyingReviewedPull(let step):
      statusBanner(
        symbol: "hourglass",
        title: String(localized: "Applying reviewed changes"),
        message: step,
        actionTitle: String(localized: "Cancel Apply"),
        actionHint: String(localized: "Stops the reviewed apply task before the next cancellable step."),
        action: { store.cancelSyncOperation() }
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

  private func pullApplyReviewBanner(_ review: PullApplyReview) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "hand.raised")
          .foregroundStyle(Color.orange)
          .frame(width: 22)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text(String(localized: "Pull apply review required"))
            .font(.callout.weight(.semibold))
          Text(String(localized: "Pull finished. Sojourn has not applied dotfiles or Brewfiles yet. Review the listed scripts, templates, and packages before applying."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(review.accessibilitySummary)
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Button(String(localized: "Apply Listed Changes...")) {
            isApplyReviewConfirmationPresented = true
          }
          .accessibilityIdentifier("sync.applyReviewedPull.review")
          .accessibilityHint(String(localized: "Opens a confirmation before running chezmoi apply and brew bundle install."))

          Button(String(localized: "Leave Unapplied")) {
            store.sync?.discardPullApplyReview()
          }
          .buttonStyle(.plain)
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("sync.discardPullApplyReview")
          .accessibilityHint(String(localized: "Clears this review without applying the already-pulled repo state."))
        }
      }

      pullApplyReviewDetails(review)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 12)
    .background(Color(nsColor: .windowBackgroundColor))
    .accessibilityIdentifier("sync.pullApplyReview")
  }

  @ViewBuilder
  private func pullApplyReviewDetails(_ review: PullApplyReview) -> some View {
    if !review.chezmoiScripts.isEmpty
      || !review.chezmoiTemplates.isEmpty
      || !review.packageReviews.isEmpty {
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          if !review.chezmoiScripts.isEmpty {
            Text(String(localized: "Chezmoi scripts"))
              .font(.caption.weight(.semibold))
            ForEach(Array(review.chezmoiScripts.enumerated()), id: \.offset) { index, script in
              Label(script, systemImage: "terminal")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("sync.pullApplyReview.script.\(index)")
                .accessibilityLabel(String(localized: "Chezmoi script \(script)"))
            }
          }
          if review.omittedChezmoiScriptCount > 0 {
            Text(String(localized: "\(review.omittedChezmoiScriptCount) more script(s) omitted from this preview."))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          if !review.chezmoiTemplates.isEmpty {
            Text(String(localized: "Chezmoi templates"))
              .font(.caption.weight(.semibold))
            ForEach(Array(review.chezmoiTemplates.enumerated()), id: \.offset) { index, template in
              Label(template, systemImage: "curlybraces")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("sync.pullApplyReview.template.\(index)")
                .accessibilityLabel(String(localized: "Chezmoi template \(template)"))
            }
          }
          if review.omittedChezmoiTemplateCount > 0 {
            Text(String(localized: "\(review.omittedChezmoiTemplateCount) more template(s) omitted from this preview."))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          if !review.packageReviews.isEmpty {
            Text(String(localized: "Brewfile entries"))
              .font(.caption.weight(.semibold))
            ForEach(Array(review.packageReviews.enumerated()), id: \.element.id) { index, item in
              VStack(alignment: .leading, spacing: 2) {
                Text("\(item.manager) \(item.package)")
                  .font(.caption.monospaced())
                Text("\(item.brewfile) - \(item.reason)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              .accessibilityElement(children: .combine)
              .accessibilityLabel(item.accessibilityLabel)
              .accessibilityIdentifier("sync.pullApplyReview.package.\(index)")
            }
          }
          if review.omittedPackageReviewCount > 0 {
            Text(String(localized: "\(review.omittedPackageReviewCount) more Brewfile entr\(review.omittedPackageReviewCount == 1 ? "y" : "ies") omitted from this preview."))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 240)
      .padding(.leading, 34)
      .accessibilityIdentifier("sync.pullApplyReview.details")
    }
  }
}
