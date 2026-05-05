// Sojourn — OverviewPane

import SwiftUI

struct OverviewPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        metrics
        quickActions
        syncSafety
        recentActivity
      }
      .padding(24)
      .frame(maxWidth: 980, alignment: .leading)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .accessibilityIdentifier("pane.overview")
    .task {
      await store.refreshContainers(forceRescan: false)
      await store.refreshGenerations()
      await store.refreshMacOSFeatureSnapshot()
      await store.refreshMasHelperStatus()
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Overview")
        .font(.title2.weight(.semibold))
      Text(
        "Machine configuration status from Brewfile, sync, snapshots, containers, and update services."
      )
      .foregroundStyle(.secondary)
    }
  }

  private var metrics: some View {
    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
      GridRow {
        metric("Packages", "\(store.brewfile?.packageCount ?? 0)", "Brewfile entries")
        metric(
          "Containers", "\(store.containers.runtimes.filter(\.installed).count)", containerSubtitle)
      }
      GridRow {
        metric("Generations", "\(store.generations.count)", "retained snapshots")
        metric("Jobs", "\(activeJobCount)", "active")
      }
    }
  }

  private func metric(_ title: String, _ value: String, _ subtitle: String) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 4) {
        Text(value)
          .font(.system(.title, design: .rounded, weight: .semibold))
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 2)
    } label: {
      Text(title)
    }
  }

  private var quickActions: some View {
    GroupBox("Actions") {
      HStack(spacing: 10) {
        Button {
          Task { await store.refreshBrewfile(force: true) }
        } label: {
          Label("Refresh Packages", systemImage: "arrow.clockwise")
        }

        Spacer()

        statusPill
      }
    }
  }

  private var syncSafety: some View {
    GroupBox("Sync Safety") {
      VStack(alignment: .leading, spacing: 10) {
        safetyRow(
          "Pull snapshot",
          "Creates a pre-operation generation before applying dotfiles or Brewfiles.",
          "externaldrive.badge.timemachine"
        )
        safetyRow(
          "Push scan",
          "Scans staged sync files and blocks high-confidence secrets.",
          "lock.shield"
        )
        safetyRow("Conflict gate", conflictSafetyText, "arrow.triangle.branch")
        safetyRow("Last sync", lastSyncText, "clock")
      }
    }
  }

  private func safetyRow(_ title: String, _ detail: String, _ symbol: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(.secondary)
        .frame(width: 18)
        .accessibilityHidden(true)
      Text(title)
        .font(.callout.weight(.semibold))
        .frame(width: 104, alignment: .leading)
      Text(detail)
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer()
    }
    .accessibilityElement(children: .combine)
  }

  private var statusPill: some View {
    Label(statusTitle, systemImage: statusIcon)
      .font(.callout)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(.quaternary, in: Capsule())
  }

  private var recentActivity: some View {
    GroupBox("Recent Activity") {
      let jobs = recentJobs
      let history = recentHistory(limit: max(0, 5 - jobs.count))
      if jobs.isEmpty && history.isEmpty {
        ContentUnavailableView(
          "No recent activity",
          systemImage: "clock",
          description: Text(
            "Run a refresh, pull, push, or snapshot operation to populate this list.")
        )
        .frame(maxWidth: .infinity, minHeight: 120)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(jobs) { job in
            activityRow(job)
            if job.id != jobs.last?.id {
              Divider()
            }
          }
          ForEach(history) { entry in
            historyRow(entry)
            if entry.id != history.last?.id {
              Divider()
            }
          }
        }
      }
    }
  }

  private func activityRow(_ job: Job) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon(for: job.state))
        .foregroundStyle(color(for: job.state))
        .frame(width: 18)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(job.label)
          .font(.callout)
        Text(jobStateLabel(job.state))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if let startedAt = job.startedAt {
        Text(Self.relativeFormatter.localizedString(for: startedAt, relativeTo: Date()))
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(job.label). \(jobStateLabel(job.state)).")
  }

  private func historyRow(_ entry: HistoryEntry) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "clock.arrow.circlepath")
        .foregroundStyle(.secondary)
        .frame(width: 18)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.description)
          .font(.callout)
        Text(Self.relativeFormatter.localizedString(for: entry.timestamp, relativeTo: Date()))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
  }

  private var activeJobCount: Int {
    store.jobRunner.jobs.suffix(100).filter { !$0.state.isTerminal }.count
  }

  private var recentJobs: [Job] {
    Array(store.jobRunner.jobs.suffix(5).reversed())
  }

  private func recentHistory(limit: Int) -> [HistoryEntry] {
    Array(store.history.suffix(limit).reversed())
  }

  private var containerSubtitle: String {
    guard let active = store.containers.activeRuntime else { return "no active runtime" }
    return "\(active.displayName) active"
  }

  private var statusTitle: String {
    if let count = syncBadgeCount, count > 0 { return "\(count) inbound commits" }
    if store.sync == nil { return "Sync not configured" }
    return "Ready"
  }

  private var statusIcon: String {
    if let count = syncBadgeCount, count > 0 { return "exclamationmark.circle" }
    if store.sync == nil { return "circle.dashed" }
    return "checkmark.circle"
  }

  private var conflictSafetyText: String {
    guard let resolver = store.conflictResolver else {
      return "Sync is not configured."
    }
    switch resolver.state {
    case .conflictPending(let commits):
      return "\(commits.count) inbound commit(s) must be resolved before push."
    case .blockedFromPush(let reason), .failed(let reason):
      return reason
    case .detecting:
      return "Checking inbound state."
    case .resolving:
      return "Resolving inbound state."
    case .resolved:
      return "Inbound state resolved; push can continue."
    case .clean:
      return "No unresolved inbound commits."
    }
  }

  private var lastSyncText: String {
    guard
      let entry = store.history.reversed().first(where: { entry in
        entry.kind == .syncPull || entry.kind == .syncPush
      })
    else {
      return "No sync history recorded."
    }
    return
      "\(entry.description) · \(Self.relativeFormatter.localizedString(for: entry.timestamp, relativeTo: Date()))"
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

  private func icon(for state: JobState) -> String {
    switch state {
    case .pending: return "clock"
    case .running: return "progress.indicator"
    case .succeeded: return "checkmark.circle"
    case .failed: return "xmark.octagon"
    case .cancelled: return "minus.circle"
    }
  }

  private func color(for state: JobState) -> Color {
    switch state {
    case .pending, .cancelled: return .secondary
    case .running: return .accentColor
    case .succeeded: return .green
    case .failed: return .red
    }
  }

  private func jobStateLabel(_ state: JobState) -> String {
    switch state {
    case .pending:
      return "Pending"
    case .running:
      return "Running"
    case .succeeded(let code):
      return "Completed with exit \(code)"
    case .failed(let reason):
      return "Failed: \(reason)"
    case .cancelled:
      return "Cancelled"
    }
  }

  private static let relativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
  }()
}
