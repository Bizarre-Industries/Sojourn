// Sojourn — Modals
//
// - BootstrapView: shown as a sheet on first run; drives BootstrapService.
// - ConflictResolutionView: three-way diff UI for SyncCoordinator pull.
// - SecretFindingsModal: 5s-locked "Commit anyway" button for high-
//   confidence secret findings per docs/SECURITY.md.
//
// See docs/ARCHITECTURE.md §11.

import SwiftUI

struct BootstrapView: View {
  let state: BootstrapState
  var onConsent: () -> Void = {}
  var onRetry: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "sparkles")
        Text("Setting up Sojourn").font(.title2.bold())
      }

      body(for: state)
    }
    .padding(24)
    .frame(width: 520)
    .accessibilityIdentifier("bootstrap.root")
  }

  @ViewBuilder
  private func body(for state: BootstrapState) -> some View {
    switch state {
    case .unknown, .probingSystem:
      ProgressView("Checking your system…")
        .accessibilityIdentifier("bootstrap.probing")

    case .reportingStatus(let inv), .awaitingUserConsent(let inv):
      VStack(alignment: .leading, spacing: 8) {
        Text("Sojourn needs to install a few things before it can sync.")
          .font(.body)
        if !inv.missing.isEmpty {
          Label("Missing: \(inv.missing.joined(separator: ", "))",
                systemImage: "exclamationmark.triangle")
        }
        if !inv.hasCLT {
          Label("Xcode Command Line Tools required", systemImage: "wrench")
        }
        Button("Install missing tools") { onConsent() }
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("bootstrap.consent")
      }

    case .installingCLT:
      ProgressView("Waiting for Xcode Command Line Tools to install…")

    case .installingBrew:
      ProgressView("Installing Homebrew (signed .pkg)…")

    case .installingMPM:
      ProgressView("Installing meta-package-manager…")

    case .installingChezmoi:
      ProgressView("Installing chezmoi…")

    case .ready:
      Label("Ready.", systemImage: "checkmark.seal.fill")
        .foregroundStyle(.green)
        .accessibilityIdentifier("bootstrap.ready")

    case .failed(let reason):
      VStack(alignment: .leading, spacing: 8) {
        Label(reason, systemImage: "exclamationmark.octagon")
          .foregroundStyle(.red)
        Button("Retry") { onRetry() }
          .accessibilityIdentifier("bootstrap.retry")
      }
    }
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
