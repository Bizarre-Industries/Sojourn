// Sojourn — MainWindowView

import SwiftUI

internal struct MainWindowView: View {
  private enum SyncAction: String, Identifiable {
    case pull
    case push

    var id: String { rawValue }
  }

  @Environment(AppStore.self) private var store
  @SceneStorage("mainWindow.selectedPane") private var selectedPaneRaw: String = Pane.dashboard.rawValue
  @State private var pendingSyncAction: SyncAction?

  private var selectedPane: Pane {
    Pane(rawValue: selectedPaneRaw) ?? .dashboard
  }

  private var selection: Binding<Pane?> {
    Binding(
      get: { selectedPane },
      set: { selectedPaneRaw = ($0 ?? .dashboard).rawValue }
    )
  }

  var body: some View {
    NavigationSplitView {
      List(selection: selection) {
        Section("Operate") {
          paneRows(Pane.operations)
        }
        Section("Configure") {
          paneRows(Pane.configuration)
        }
        Section("Maintain") {
          paneRows(Pane.maintenance)
        }
      }
      .listStyle(.sidebar)
      .navigationTitle("Sojourn")
      .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
    } detail: {
      detail(for: selectedPane)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(selectedPane.label)
        .toolbar { mainToolbar }
    }
    .frame(minWidth: 1120, idealWidth: 1240, minHeight: 700, idealHeight: 780)
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
    .confirmationDialog(
      syncConfirmationTitle,
      isPresented: syncConfirmationPresented,
      titleVisibility: .visible
    ) {
      syncConfirmationActions
    } message: {
      Text(syncConfirmationMessage)
    }
  }

  @ViewBuilder
  private func paneRows(_ panes: [Pane]) -> some View {
    ForEach(panes) { pane in
      Label {
        HStack(spacing: 6) {
          Text(pane.label)
          if pane == .sync, let count = syncBadgeCount, count > 0 {
            Text("\(count)")
              .font(.caption2.monospacedDigit())
              .foregroundStyle(.secondary)
              .padding(.horizontal, 5)
              .padding(.vertical, 1)
              .background(.quaternary, in: Capsule())
              .accessibilityLabel("\(count) inbound commits pending")
          }
        }
      } icon: {
        Image(systemName: pane.icon)
      }
      .tag(pane)
      .accessibilityIdentifier("sidebar.\(pane.rawValue)")
      .accessibilityLabel(sidebarAccessibilityLabel(for: pane))
    }
  }

  private func sidebarAccessibilityLabel(for pane: Pane) -> String {
    if pane == .sync, let count = syncBadgeCount, count > 0 {
      return "\(pane.label), \(count) inbound commits pending"
    }
    return pane.label
  }

  @ToolbarContentBuilder
  private var mainToolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Button {
        Task { await refreshSelectedPane() }
      } label: {
        Label("Refresh", systemImage: "arrow.clockwise")
      }
      .accessibilityIdentifier("toolbar.refresh")

      Button {
        pendingSyncAction = .pull
      } label: {
        Label("Pull and Apply", systemImage: "arrow.down")
      }
      .disabled(store.sync == nil)
      .disabled(syncActionDisabled)
      .accessibilityIdentifier("toolbar.pull")
      .accessibilityHint("Creates a generation, fetches remote changes, and may apply dotfiles and Brewfiles.")

      Button {
        pendingSyncAction = .push
      } label: {
        Label("Push After Scan", systemImage: "arrow.up")
      }
      .disabled(store.sync == nil || syncActionDisabled || store.conflictResolver?.canPush == false)
      .accessibilityIdentifier("toolbar.push")
      .accessibilityHint("Stages sync files, runs gitleaks on the staged index, commits clean changes, and pushes to origin.")

      if case .applyingReviewedPull = store.sync?.phase {
        Button {
          store.cancelSyncOperation()
        } label: {
          Label("Cancel Apply", systemImage: "xmark.circle")
        }
        .accessibilityIdentifier("toolbar.cancel-reviewed-apply")
        .accessibilityHint("Stops the reviewed pull apply task before the next cancellable step.")
      }
    }

    ToolbarItem(placement: .status) {
      Label(toolbarStatusTitle, systemImage: toolbarStatusIcon)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("toolbar.status")
        .accessibilityLabel(toolbarStatusTitle)
        .accessibilityHint(toolbarStatusHint)
    }
  }

  private func refreshSelectedPane() async {
    switch selectedPane {
    case .dashboard:
      async let brewfile: Void = store.refreshBrewfile(force: true)
      async let containers: Void = store.refreshContainers(forceRescan: false)
      async let masHelper: Void = store.refreshMasHelperStatus()
      async let generations: Void = store.refreshGenerations()
      async let features: Void = store.refreshMacOSFeatureSnapshot(force: true)
      _ = await (brewfile, containers, masHelper, generations, features)
    case .packages:
      await store.refreshBrewfile(force: true)
      await store.refreshMasHelperStatus()
    case .containers:
      await store.refreshContainers(forceRescan: true)
    case .generations:
      await store.refreshGenerations()
    case .macosFeatures:
      await store.refreshMacOSFeatureSnapshot(force: true)
    case .preferences:
      await store.refreshPreferenceDomains()
    case .sync:
      break
    case .machines:
      break
    case .advisories:
      await store.refreshAdvisorySnapshot(force: true)
    case .jobs:
      break
    case .settings:
      break
    }
  }

  private var toolbarStatusTitle: String {
    if let activeOperationTitle {
      return activeOperationTitle
    }
    if case .awaitingPullApplyReview = store.sync?.phase {
      return String(localized: "Apply review waiting")
    }
    if syncActionDisabled, store.sync != nil {
      return String(localized: "Sync busy")
    }
    if let count = syncBadgeCount, count > 0 {
      return String(localized: "\(count) inbound")
    }
    if case .failed = store.sync?.phase {
      return String(localized: "Sync needs attention")
    }
    if store.sync == nil {
      return String(localized: "Sync off")
    }
    return String(localized: "Ready")
  }

  private var toolbarStatusIcon: String {
    if activeOperationTitle != nil {
      return "hourglass"
    }
    if case .awaitingPullApplyReview = store.sync?.phase {
      return "exclamationmark.triangle"
    }
    if syncActionDisabled, store.sync != nil {
      return "hourglass"
    }
    if let count = syncBadgeCount, count > 0 {
      return "exclamationmark.circle"
    }
    if case .failed = store.sync?.phase {
      return "xmark.octagon"
    }
    if store.sync == nil {
      return "circle.dashed"
    }
    return "checkmark.circle"
  }

  private var toolbarStatusHint: String {
    if case .failed = store.sync?.phase {
      return String(localized: "Open Sync for the failure reason and recovery steps.")
    }
    if case .awaitingPullApplyReview = store.sync?.phase {
      return String(localized: "Open Sync. Pulled scripts, templates, or packages have not been applied.")
    }
    if let count = syncBadgeCount, count > 0 {
      return String(localized: "\(count) inbound commit(s) need review in Sync.")
    }
    if activeOperationTitle != nil {
      return String(localized: "An operation is currently running.")
    }
    return ""
  }

  private var activeOperationTitle: String? {
    if let phase = store.sync?.phase {
      switch phase {
      case .pulling:
        return String(localized: "Pulling")
      case .resolvingConflicts:
        return String(localized: "Resolving conflicts")
      case .scanningSecrets:
        return String(localized: "Scanning staged files")
      case .pushing:
        return String(localized: "Pushing")
      case .applyingReviewedPull(let step):
        return String(localized: "Applying: \(step)")
      case .idle, .awaitingPullDecision, .awaitingPullApplyReview, .done, .failed:
        break
      }
    }
    return store.jobRunner.jobs.last(where: { !$0.state.isTerminal })?.label
  }

  private var syncBadgeCount: Int? {
    guard let resolver = store.conflictResolver else { return nil }
    switch resolver.state {
    case .conflictPending(let commits): return commits.count
    case .blockedFromPush, .failed:
      return resolver.pendingCommits.isEmpty ? 1 : resolver.pendingCommits.count
    case .clean, .detecting, .resolving, .resolved:
      return nil
    }
  }

  private var syncActionDisabled: Bool {
    if case .awaitingPullApplyReview = store.sync?.phase {
      return true
    }
    if store.sync?.isOperationActive == true {
      return true
    }
    switch store.conflictResolver?.state {
    case .detecting, .resolving:
      return true
    case .clean, .conflictPending, .blockedFromPush, .failed, .resolved, nil:
      return false
    }
  }

  private var syncConfirmationPresented: Binding<Bool> {
    Binding(
      get: { pendingSyncAction != nil },
      set: { isPresented in
        if !isPresented {
          pendingSyncAction = nil
        }
      }
    )
  }

  private var syncConfirmationTitle: String {
    switch pendingSyncAction {
    case .pull: return String(localized: "Pull and apply from data repo?")
    case .push: return String(localized: "Push local changes after scan?")
    case nil: return String(localized: "Confirm sync")
    }
  }

  private var syncConfirmationMessage: String {
    switch pendingSyncAction {
    case .pull:
      return String(localized: "Pull fetches remote changes, then either pauses for review or creates a generation before applying dotfiles and Brewfiles. Review appears when pulled scripts, templates, or packages need a second gesture.")
    case .push:
      return String(localized: "Push stages sync files, runs gitleaks on staged content, refuses unresolved inbound commits, captures a generation only after the scan passes, commits clean sync paths, and pushes to origin. Blocked scans stop before snapshot capture.")
    case nil:
      return ""
    }
  }

  @ViewBuilder
  private var syncConfirmationActions: some View {
    switch pendingSyncAction {
    case .pull:
      Button("Pull and Apply") {
        pendingSyncAction = nil
        Task {
          await store.pullSync()
          routeToSyncIfAttentionNeeded()
        }
      }
      Button("Cancel", role: .cancel) {
        pendingSyncAction = nil
      }
    case .push:
      Button("Push After Scan") {
        pendingSyncAction = nil
        Task {
          await store.pushSync()
          routeToSyncIfAttentionNeeded()
        }
      }
      Button("Cancel", role: .cancel) {
        pendingSyncAction = nil
      }
    case nil:
      EmptyView()
    }
  }

  private func routeToSyncIfAttentionNeeded() {
    switch store.sync?.phase {
    case .awaitingPullDecision, .awaitingPullApplyReview, .applyingReviewedPull, .failed:
      selectedPaneRaw = Pane.sync.rawValue
      return
    case .idle, .pulling, .resolvingConflicts, .scanningSecrets, .pushing, .done, nil:
      break
    }

    switch store.conflictResolver?.state {
    case .conflictPending, .blockedFromPush, .failed:
      selectedPaneRaw = Pane.sync.rawValue
    case .clean, .detecting, .resolving, .resolved, nil:
      break
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
    case .containers:    ContainersPane {
      selectedPaneRaw = Pane.packages.rawValue
    }
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
