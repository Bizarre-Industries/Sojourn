// Sojourn - Menu bar root view

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct MenuBarRootView: View {
  @Environment(AppStore.self) private var store
  @State private var pendingSyncAction: MenuBarSyncAction?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        SojournMenuBarIconView(size: 14, color: .bzrLime)
        Text("SOJOURN")
          .font(.bzrStencil(size: 14, weight: .heavy))
          .tracking(1.6)
          .foregroundStyle(Color.txtPrimary)
        Spacer()
        StatusDot(kind: syncStatus.dot)
          .accessibilityLabel(syncStatus.accessibilityLabel)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .overlay(
        Rectangle().fill(Color.hairline).frame(height: 0.5),
        alignment: .bottom
      )

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(machineName.uppercased())
            .font(.bzrMono(size: 10, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Color.bzrLimeText)
          Text("-")
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
          Text(syncRelative)
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
        }
        Text(syncStatus.label)
          .font(.bzrBody(size: 11))
          .foregroundStyle(Color.txtSecondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)

      VStack(spacing: 6) {
        Button {
          Task { await store.refreshBrewfile() }
        } label: {
          menuButtonLabel("Update Brewfile", systemImage: "arrow.clockwise")
        }
        .buttonStyle(GlassCapsuleButtonStyle())
        .accessibilityIdentifier("menubar.update")

        syncButton(.pull)
          .accessibilityIdentifier("menubar.pull")
        syncButton(.push)
          .accessibilityIdentifier("menubar.push")
        syncButton(.sync)
          .accessibilityIdentifier("menubar.sync")

        Button {
          NSApp.activate(ignoringOtherApps: true)
        } label: {
          menuButtonLabel(String(localized: "Open Sojourn"), systemImage: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(GlassPrimaryButtonStyle())
        .accessibilityIdentifier("menubar.review-sync")
        .accessibilityHint(openSojournHint)

        if !store.sparkleService.statusMessage.isEmpty {
          HStack(alignment: .top, spacing: 6) {
            Image(systemName: "arrow.down.circle")
              .font(.system(size: 10, weight: .semibold))
              .accessibilityHidden(true)
            Text(store.sparkleService.statusMessage)
              .fixedSize(horizontal: false, vertical: true)
            Spacer()
          }
          .font(.bzrBody(size: 10))
          .foregroundStyle(Color.txtSecondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 6)
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(Color.adaptiveLighten(0.04))
          )
          .accessibilityIdentifier("menubar.updateStatus")
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Update status: \(store.sparkleService.statusMessage)")
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 6)

      VStack(spacing: 0) {
        Rectangle().fill(Color.hairline).frame(height: 0.5)
        HStack(spacing: 6) {
          Button("Open Sojourn...") {
            NSApp.activate(ignoringOtherApps: true)
          }
          .buttonStyle(GlassGhostButtonStyle())
          .accessibilityIdentifier("menubar.open")
          Spacer()
          Button("Quit") { NSApp.terminate(nil) }
            .buttonStyle(GlassGhostButtonStyle())
            .accessibilityIdentifier("menubar.quit")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
      }
    }
    .frame(width: 300, alignment: .leading)
    .confirmationDialog(
      pendingSyncAction?.confirmationTitle ?? "Confirm sync",
      isPresented: confirmationPresented,
      titleVisibility: .visible,
      presenting: pendingSyncAction
    ) { action in
      Button(action.confirmButtonTitle) {
        run(action)
      }
      Button("Cancel", role: .cancel) {
        pendingSyncAction = nil
      }
    } message: { action in
      Text(action.confirmationMessage)
    }
  }

  private var confirmationPresented: Binding<Bool> {
    Binding(
      get: { pendingSyncAction != nil },
      set: { isPresented in
        if !isPresented {
          pendingSyncAction = nil
        }
      }
    )
  }

  private var machineName: String {
    Host.current().localizedName ?? "this-mac"
  }

  private var syncRelative: String {
    if let last = store.settings.lastSyncTime {
      return last.formatted(.relative(presentation: .named))
    }
    return "never synced"
  }

  private var syncStatus: MenuBarSyncStatus {
    MenuBarSyncStatus(
      phase: store.sync?.phase,
      resolverState: store.conflictResolver?.state
    )
  }

  private var openSojournHint: String {
    if case .awaitingPullApplyReview = store.sync?.phase {
      return String(localized: "Opens Sojourn so pulled scripts, templates, and packages can be reviewed before applying.")
    }
    if case .applyingReviewedPull = store.sync?.phase {
      return String(localized: "Opens Sojourn so the reviewed apply progress can be monitored or cancelled.")
    }
    return String(localized: "Opens Sojourn so pull, push, and conflict details can be reviewed in the main window.")
  }

  private func syncButton(_ action: MenuBarSyncAction) -> some View {
    Button {
      pendingSyncAction = action
    } label: {
      menuButtonLabel(action.title, systemImage: action.systemImage)
    }
    .buttonStyle(GlassCapsuleButtonStyle())
    .disabled(store.sync == nil || actionDisabled(action))
    .accessibilityHint(action.accessibilityHint)
  }

  private func menuButtonLabel(_ title: String, systemImage: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.system(size: 10, weight: .semibold))
        .accessibilityHidden(true)
      Text(title)
      Spacer()
    }
  }

  private func actionDisabled(_ action: MenuBarSyncAction) -> Bool {
    if case .awaitingPullApplyReview = store.sync?.phase {
      return true
    }
    if store.sync?.isOperationActive == true {
      return true
    }
    switch action {
    case .pull:
      return false
    case .push, .sync:
      return store.conflictResolver?.canPush == false
    }
  }

  private func run(_ action: MenuBarSyncAction) {
    pendingSyncAction = nil
    Task {
      switch action {
      case .pull:
        await store.pullSync()
      case .push:
        await store.pushSync(message: "sojourn: menu-bar push")
      case .sync:
        await store.pullSync()
        if !syncNeedsAttention {
          await store.pushSync(message: "sojourn: menu-bar sync")
        }
      }
    }
  }

  private var syncNeedsAttention: Bool {
    if case .failed = store.sync?.phase {
      return true
    }
    if case .awaitingPullDecision = store.sync?.phase {
      return true
    }
    if case .awaitingPullApplyReview = store.sync?.phase {
      return true
    }
    if case .applyingReviewedPull = store.sync?.phase {
      return true
    }
    return store.conflictResolver?.canPush == false
  }
}

private enum MenuBarSyncAction: Identifiable {
  case pull
  case push
  case sync

  var id: String { title }

  var title: String {
    switch self {
    case .pull: return "Pull and Apply"
    case .push: return "Push After Scan"
    case .sync: return "Sync After Pull"
    }
  }

  var systemImage: String {
    switch self {
    case .pull: return "arrow.down"
    case .push: return "arrow.up"
    case .sync: return "arrow.triangle.2.circlepath"
    }
  }

  var confirmationTitle: String {
    switch self {
    case .pull: return "Pull and apply from data repo?"
    case .push: return "Push local changes after scan?"
    case .sync: return "Pull, then push after scan?"
    }
  }

  var confirmButtonTitle: String { title }

  var confirmationMessage: String {
    switch self {
    case .pull:
      return "Pull fetches remote changes, then either pauses for review or creates a generation before applying dotfiles and Brewfiles. Review appears when pulled scripts, templates, or packages need a second gesture."
    case .push:
      return "Push stages sync files, scans staged content with gitleaks, captures a generation only after the scan passes, commits clean sync paths, and pushes to origin. Blocked scans stop before snapshot capture."
    case .sync:
      return "Sync runs Pull and Apply first. If pull does not pause for conflict or apply review, it stages sync files, scans staged content, captures a generation only after the scan passes, commits clean sync paths, and pushes to origin."
    }
  }

  var accessibilityHint: String {
    switch self {
    case .pull:
      return "Confirms before pulling and applying remote changes."
    case .push:
      return "Confirms before staging sync files, scanning staged content, and pushing."
    case .sync:
      return "Confirms before pulling, then pushing only if no conflict needs review."
    }
  }
}

private struct MenuBarSyncStatus {
  let dot: StatusDotKind
  let label: String

  var accessibilityLabel: String {
    "Sync status: \(label)"
  }

  private init(dot: StatusDotKind, label: String) {
    self.dot = dot
    self.label = label
  }

  init(phase: SyncPhase?, resolverState: ConflictResolver.State?) {
    guard let phase else {
      self.init(dot: .warn, label: "Sync not configured")
      return
    }

    switch phase {
    case .pulling:
      self.init(dot: .lime, label: "Pulling and applying")
    case .resolvingConflicts:
      self.init(dot: .warn, label: "Resolving conflicts")
    case .awaitingPullDecision(let commits):
      self.init(dot: .warn, label: "\(commits.count) inbound commit(s)")
    case .awaitingPullApplyReview:
      self.init(dot: .warn, label: String(localized: "Apply review waiting"))
    case .applyingReviewedPull(let step):
      self.init(dot: .lime, label: String(localized: "Applying \(step)"))
    case .scanningSecrets:
      self.init(dot: .warn, label: "Scanning staged files")
    case .pushing:
      self.init(dot: .lime, label: "Pushing after scan")
    case .done(let kind):
      self.init(dot: .ok, label: "Last \(kind.rawValue) complete")
    case .failed:
      self.init(dot: .danger, label: "Sync needs attention")
    case .idle:
      self.init(resolverState: resolverState)
    }
  }

  private init(resolverState: ConflictResolver.State?) {
    switch resolverState {
    case .detecting:
      self.init(dot: .lime, label: "Checking inbound")
    case .conflictPending(let commits):
      self.init(dot: .warn, label: "\(commits.count) inbound commit(s)")
    case .resolving:
      self.init(dot: .warn, label: "Resolving conflicts")
    case .blockedFromPush:
      self.init(dot: .danger, label: "Push blocked")
    case .failed:
      self.init(dot: .danger, label: "Sync check failed")
    case .clean, .resolved, nil:
      self.init(dot: .ok, label: "Writer - clean")
    }
  }
}
