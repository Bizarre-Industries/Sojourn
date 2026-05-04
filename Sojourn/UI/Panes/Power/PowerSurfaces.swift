// Sojourn — Power surfaces
//
// Each surface exposes a backend that was previously implicit. Power panes
// keep their stable identifiers while individual service-backed details are
// wired in stages.

import SwiftUI

// MARK: - Job Inspector (routed: .jobs)

struct JobInspectorPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Jobs")
            .font(.title2.weight(.semibold))
          Text("Recent JobRunner activity, subprocess state, and exit status.")
            .foregroundStyle(.secondary)
        }

        if recentJobs.isEmpty {
          ContentUnavailableView(
            "No jobs",
            systemImage: "terminal",
            description: Text("Refresh, pull, push, snapshot, and scan operations appear here while running and after completion.")
          )
          .frame(maxWidth: .infinity, minHeight: 220)
        } else {
          if let currentJob {
            CurrentJobView(job: currentJob)
          }

          GroupBox {
            VStack(alignment: .leading, spacing: 0) {
              ForEach(recentJobs) { job in
                jobRow(job)
                if job.id != recentJobs.last?.id {
                  Divider()
                }
              }
            }
          }
        }
      }
      .padding(24)
      .frame(maxWidth: 900, alignment: .leading)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .accessibilityIdentifier("pane.jobs")
  }

  private var recentJobs: [Job] {
    Array(store.jobRunner.jobs.suffix(100).reversed())
  }

  private var currentJob: Job? {
    store.jobRunner.jobs.last { !$0.state.isTerminal }
  }

  private func jobRow(_ job: Job) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon(for: job.state))
        .foregroundStyle(color(for: job.state))
        .frame(width: 22)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(job.label)
          .font(.callout.weight(.semibold))
        Text(job.id.rawValue.uuidString)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text(label(for: job.state))
        .font(.caption)
        .foregroundStyle(color(for: job.state))
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(job.label). \(label(for: job.state)).")
  }

  private func icon(for state: JobState) -> String {
    switch state {
    case .pending:   return "clock"
    case .running:   return "progress.indicator"
    case .succeeded: return "checkmark.circle"
    case .failed:    return "xmark.octagon"
    case .cancelled: return "minus.circle"
    }
  }

  private func color(for state: JobState) -> Color {
    switch state {
    case .pending, .cancelled: return .secondary
    case .running:             return .accentColor
    case .succeeded:           return .green
    case .failed:              return .red
    }
  }

  private func label(for state: JobState) -> String {
    switch state {
    case .pending:
      return "Pending"
    case .running:
      return "Running"
    case .succeeded(let code):
      return "Exit \(code)"
    case .failed(let reason):
      return "Failed: \(reason)"
    case .cancelled:
      return "Cancelled"
    }
  }
}

private struct CurrentJobView: View {
  @Environment(AppStore.self) private var store
  let job: Job
  @State private var lastLogLine = "No log output yet."

  var body: some View {
    GroupBox("Current Operation") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "progress.indicator")
          .foregroundStyle(Color.accentColor)
          .frame(width: 22)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(job.label)
            .font(.callout.weight(.semibold))
          Text(phaseLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(lastLogLine)
            .font(.caption.monospaced())
            .foregroundStyle(.tertiary)
            .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current operation: \(job.label). \(phaseLabel). Last log line: \(lastLogLine).")

        Spacer()

        Button("Cancel") {
          store.jobRunner.cancel(job.id)
        }
        .disabled(!store.jobRunner.canCancel(job.id))
        .accessibilityIdentifier("jobs.cancel-current")
        .accessibilityLabel("Cancel current operation")
      }
      .padding(.vertical, 4)
    }
    .task(id: job.logBufferID.rawValue) {
      await followLog()
    }
  }

  private var phaseLabel: String {
    switch job.state {
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

  private func followLog() async {
    guard let buffer = store.jobRunner.buffer(job.logBufferID) else { return }
    if let line = await buffer.latestLine() {
      lastLogLine = displayText(for: line)
    }
    let stream = await buffer.subscribeLive()
    for await line in stream {
      lastLogLine = displayText(for: line)
    }
  }

  private func displayText(for line: LogLine) -> String {
    line.text.isEmpty ? "(blank log line)" : line.text
  }
}

// MARK: - Schedule Inspector

struct ScheduleInspectorPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "SCHEDULE · NSBackgroundActivityScheduler",
      title: "SCHEDULE.",
      subtitle: "Background tasks, skip-log entries, and next-fire timing render here once scheduler state is exposed."
    )
    .accessibilityIdentifier("pane.schedule")
  }
}

// MARK: - age Keys

struct AgeKeysPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "AGE · X25519 · KeychainBroker",
      title: "AGE KEYS.",
      subtitle: "Local identity at ~/.config/chezmoi/key.txt and per-machine recipients in .sojourn/recipients.txt."
    )
    .accessibilityIdentifier("pane.age")
  }
}

// MARK: - chezmoi Templates

struct ChezmoiTemplatesPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "TEMPLATES · chezmoi data · managed · diff",
      title: "TEMPLATES.",
      subtitle: "Per-host conditionals and variables surfaced from `chezmoi data --format=json`."
    )
    .accessibilityIdentifier("pane.chezmoi-templates")
  }
}

// MARK: - gitleaks Rules

struct GitleaksRulesPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "RULES · gitleaks 8.30.1 · MIT · bundled",
      title: "RULES & ALLOWLIST.",
      subtitle: "Builtin pattern list, per-repo allowlist entries, hit counts, and expiry status."
    )
    .accessibilityIdentifier("pane.gitleaks-rules")
  }
}

// MARK: - Authorization

struct AuthorizationPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "AUTHORIZATION · TCC · SMAppService · Touch ID",
      title: "AUTHORIZATION.",
      subtitle: "FDA grant status, helper-tool registration, and Touch ID-for-sudo state."
    )
    .accessibilityIdentifier("pane.authorization")
  }
}

// MARK: - Manager Detail

struct ManagerDetailPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "MANAGER DETAIL · per-ecosystem deep-dive",
      title: "MANAGER DETAIL.",
      subtitle: "Drill down into a single Brewfile entry tier with per-package install and outdated state."
    )
    .accessibilityIdentifier("pane.manager-detail")
  }
}

// MARK: - Backups

struct BackupsPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "BACKUPS · ~/Library/Application Support/Sojourn/generations/",
      title: "BACKUPS.",
      subtitle: "Pre-operation tarball list with per-snapshot stats and restore state."
    )
    .accessibilityIdentifier("pane.backups")
  }
}

// MARK: - defaults Discover

struct DefaultsDiscoverPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "DEFAULTS DISCOVER · cfprefsd · plutil",
      title: "DEFAULTS DISCOVER.",
      subtitle: "Record mode for preference writes, surfacing which domain and key changed."
    )
    .accessibilityIdentifier("pane.defaults-discover")
  }
}

// MARK: - Repo Setup

struct RepoSetupPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "REPO SETUP · git · GitHub Device Flow",
      title: "REPO SETUP.",
      subtitle: "First-run sync setup for choosing a remote and creating the .sojourn scaffold."
    )
    .accessibilityIdentifier("pane.repo-setup")
  }
}
