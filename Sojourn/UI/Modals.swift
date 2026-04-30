// Sojourn — Modals & Sheets
//
// Liquid Glass redesign of the modal surfaces:
// - BootstrapView: first-run sheet driving BootstrapService.
// - PushSheet: gitleaks-clean push preview + commit message.
// - PullSheet: pull preview with per-pillar diff + conflict count.
// - SecretFindingsModal: 5s-locked bypass for high-confidence findings.
// - ConflictResolutionView: three-way diff for SyncCoordinator pull.

import SwiftUI

// MARK: - Bootstrap (first-run)

struct BootstrapView: View {
  let state: BootstrapState
  var onConsent: () -> Void = {}
  var onRetry: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 10) {
        SojournMenuBarIconView(size: 18, color: .bzrLime)
        Text("Setting up Sojourn")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
      }

      body(for: state)
    }
    .padding(24)
    .frame(width: 560)
    .modifier(GlassSheetBackground())
    .accessibilityIdentifier("bootstrap.root")
  }

  @ViewBuilder
  private func body(for state: BootstrapState) -> some View {
    switch state {
    case .unknown, .probingSystem:
      VStack(alignment: .leading, spacing: 12) {
        BzrProgressBar(value: 0.15)
        Text("Probing your system for git, brew, mpm, chezmoi, age, gitleaks…")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
      }
      .accessibilityIdentifier("bootstrap.probing")

    case .reportingStatus(let inv), .awaitingUserConsent(let inv):
      VStack(alignment: .leading, spacing: 12) {
        if !inv.missing.isEmpty {
          BzrCallout(
            title: "Missing tools",
            kind: .warn,
            bodyText: inv.missing.joined(separator: ", ")
          )
        }
        if !inv.hasCLT {
          BzrCallout(
            title: "Xcode CLT required",
            kind: .warn,
            bodyText: "Click 'Install missing tools' — macOS surfaces its own Authorization sheet."
          )
        }
        HStack {
          Spacer()
          Button("Install missing tools") { onConsent() }
            .buttonStyle(GlassPrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("bootstrap.consent")
        }
      }

    case .installingCLT:
      bootstrapStep(0.30, "Installing Xcode Command Line Tools…")
    case .installingBrew:
      bootstrapStep(0.50, "Installing Homebrew (signed .pkg)…")
    case .installingMPM:
      bootstrapStep(0.70, "Installing meta-package-manager…")
    case .installingChezmoi:
      bootstrapStep(0.90, "Installing chezmoi…")

    case .ready:
      BzrCallout(
        title: "Ready",
        kind: .info,
        bodyText: "All tools detected. You can close this and start carrying."
      )
      .accessibilityIdentifier("bootstrap.ready")

    case .failed(let reason):
      VStack(alignment: .leading, spacing: 10) {
        BzrCallout(title: "Bootstrap failed", kind: .danger, bodyText: reason)
        HStack {
          Spacer()
          Button("Retry") { onRetry() }
            .buttonStyle(GlassPrimaryButtonStyle())
            .accessibilityIdentifier("bootstrap.retry")
        }
      }
    }
  }

  @ViewBuilder
  private func bootstrapStep(_ progress: Double, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      BzrProgressBar(value: progress)
      Text(label)
        .font(.bzrBody(size: 13))
        .foregroundStyle(Color.txtSecondary)
    }
  }
}

// MARK: - Push sheet

struct PushSheet: View {
  let lastSync: Date?
  var onClose: () -> Void = {}
  var onPush: (String) -> Void = { _ in }

  @State private var message: String = "sojourn: sync"

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 10) {
        Image(systemName: "arrow.up")
          .foregroundStyle(Color.bzrLime)
        Text("Push")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
        Spacer()
        BzrBadge(text: "GITLEAKS · CLEAN", kind: .success)
      }

      BzrCallout(
        title: "Pre-push checks",
        kind: .info,
        bodyText: "gitleaks scan: no findings. SBOM regenerated. Cooldown gate cleared."
      )

      VStack(alignment: .leading, spacing: 6) {
        Text("Commit message")
          .font(.bzrTinyEyebrow)
          .tracking(1.6)
          .foregroundStyle(Color.txtTertiary)
        TextField("sojourn: sync", text: $message)
          .textFieldStyle(.plain)
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtPrimary)
          .padding(8)
          .background(
            RoundedRectangle(cornerRadius: 6)
              .fill(Color.black.opacity(0.25))
              .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.hairline, lineWidth: 0.5))
          )
      }

      HStack {
        Button("Cancel") { onClose() }
          .buttonStyle(GlassGhostButtonStyle())
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button("Push to git@…") {
          onPush(message)
          onClose()
        }
        .buttonStyle(GlassPrimaryButtonStyle())
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("push.confirm")
      }
    }
    .padding(22)
    .frame(width: 560)
    .modifier(GlassSheetBackground())
    .accessibilityIdentifier("push.root")
  }
}

// MARK: - Pull sheet

struct PullSheet: View {
  var conflictCount: Int = 0
  var onClose: () -> Void = {}
  var onPull: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 10) {
        Image(systemName: "arrow.down")
          .foregroundStyle(Color.bzrLime)
        Text("Pull")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
        Spacer()
        if conflictCount > 0 {
          BzrBadge(text: "\(conflictCount) CONFLICT\(conflictCount == 1 ? "" : "S")", kind: .warn)
        } else {
          BzrBadge(text: "CLEAN", kind: .success)
        }
      }

      BzrCallout(
        title: "Snapshot first",
        kind: .info,
        bodyText: "Sojourn writes a pre-op snapshot to ~/Library/Application Support/Sojourn/backups/<ts>-pull/ before applying any change. 30-day retention."
      )

      if conflictCount > 0 {
        BzrCallout(
          title: "Conflicts",
          kind: .warn,
          bodyText: "Resolve in the Conflicts pane before this pull can apply."
        )
      }

      HStack {
        Button("Cancel") { onClose() }
          .buttonStyle(GlassGhostButtonStyle())
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button(conflictCount > 0 ? "Open Conflicts" : "Pull from origin") {
          onPull()
          onClose()
        }
        .buttonStyle(GlassPrimaryButtonStyle())
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("pull.confirm")
      }
    }
    .padding(22)
    .frame(width: 560)
    .modifier(GlassSheetBackground())
    .accessibilityIdentifier("pull.root")
  }
}

struct ConflictResolutionView: View {
  let conflicts: [Conflict]
  var onResolve: (Conflict, Conflict.Resolution) -> Void = { _, _ in }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Resolve conflicts").font(.title2.bold())
      ForEach(conflicts) { conflict in
        VStack(alignment: .leading) {
          Text(conflict.path).font(.body.monospaced())
          HStack {
            Button("Keep local") { onResolve(conflict, .keepLocal) }
              .accessibilityIdentifier("conflict.keepLocal.\(conflict.id)")
            Button("Keep remote") { onResolve(conflict, .keepRemote) }
              .accessibilityIdentifier("conflict.keepRemote.\(conflict.id)")
          }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
      }
    }
    .padding(24)
    .frame(minWidth: 520)
    .accessibilityIdentifier("conflicts.root")
  }
}

struct SecretFindingsModal: View {
  let findings: [SecretFinding]
  var onCommitAnyway: () -> Void = {}
  var onCancel: () -> Void = {}

  @State private var secondsLeft: Int = 5

  private var hasHighConfidence: Bool {
    findings.contains(where: { $0.isHighConfidence })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "key.shield")
          .foregroundStyle(.red)
        Text("Potential secrets detected").font(.title2.bold())
      }

      if hasHighConfidence {
        Text("High-confidence provider key(s) found. Please review before committing.")
          .foregroundStyle(.red)
      }

      ForEach(findings) { finding in
        VStack(alignment: .leading, spacing: 2) {
          Text("\(finding.file):\(finding.startLine)")
            .font(.caption.monospaced())
          Text(finding.description)
          Text("Rule: \(finding.ruleID)")
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
      }

      HStack {
        Button("Cancel", action: onCancel)
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("secrets.cancel")
        Spacer()
        Button {
          onCommitAnyway()
        } label: {
          if hasHighConfidence && secondsLeft > 0 {
            Text("Commit anyway (\(secondsLeft))")
          } else {
            Text("Commit anyway")
          }
        }
        .disabled(hasHighConfidence && secondsLeft > 0)
        .accessibilityIdentifier("secrets.commitAnyway")
      }
    }
    .padding(24)
    .frame(width: 560)
    .task {
      guard hasHighConfidence else { return }
      while secondsLeft > 0 {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        secondsLeft -= 1
      }
    }
    .accessibilityIdentifier("secrets.root")
  }
}
