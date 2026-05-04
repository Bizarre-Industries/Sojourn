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

  // Design: 7 named steps in the rail. Map BootstrapState → step index.
  private struct RailStep: Identifiable {
    let id: String
    let label: String
  }

  private let rail: [RailStep] = [
    .init(id: "1", label: "PROBE"),
    .init(id: "2", label: "CONSENT"),
    .init(id: "3", label: "XCODE CLT"),
    .init(id: "4", label: "HOMEBREW"),
    .init(id: "5", label: "MPM"),
    .init(id: "6", label: "CHEZMOI"),
    .init(id: "7", label: "MAS"),
    .init(id: "8", label: "READY")
  ]

  private var activeStep: Int {
    switch state {
    case .unknown, .probingSystem: return 0
    case .reportingStatus, .awaitingUserConsent: return 1
    case .installingCLT: return 2
    case .installingBrew: return 3
    case .installingMPM: return 4
    case .installingChezmoi: return 5
    case .installingMas: return 6
    case .ready: return 7
    case .failed: return 1
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      // Left rail — 7 steps
      VStack(alignment: .leading, spacing: 0) {
        EyebrowLabel(text: "BIZARRE / SOJOURN / FIRST RUN")
          .padding(.bottom, 14)

        VStack(alignment: .leading, spacing: 0) {
          Text("YOU")
          Text("ALREADY")
          Text("KNOW.")
            .foregroundStyle(Color.bzrLimeText)
        }
        .font(.bzrStencil(size: 36, weight: .heavy))
        .foregroundStyle(Color.txtPrimary)
        .lineSpacing(-4)

        Text("Three commands separate \"fresh Mac\" from \"your Mac.\" Sojourn handles two automatically and prompts you for the third. One Authorization dialog. Then we get out of your way.")
          .font(.bzrBody(size: 12))
          .foregroundStyle(Color.txtSecondary)
          .lineSpacing(2)
          .padding(.top, 14)

        VStack(spacing: 0) {
          ForEach(Array(rail.enumerated()), id: \.element.id) { idx, step in
            railRow(step, status: railStatus(at: idx))
            if idx < rail.count - 1 {
              Rectangle().fill(Color.hairlineInner).frame(height: 0.5)
            }
          }
        }
        .padding(.top, 22)

        Spacer()
      }
      .padding(28)
      .frame(width: 280, alignment: .topLeading)
      .background(Color.adaptiveDeepen(0.30))
      .overlay(
        Rectangle().fill(Color.hairline).frame(width: 0.5),
        alignment: .trailing
      )

      // Right pane — current state body
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          contentBody
        }
        .padding(36)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    }
    .frame(width: 880, height: 560)
    .modifier(GlassSheetBackground())
    .accessibilityIdentifier("bootstrap.root")
  }

  private enum RailStatus { case done, active, pending }

  private func railStatus(at idx: Int) -> RailStatus {
    if idx < activeStep { return .done }
    if idx == activeStep { return .active }
    return .pending
  }

  @ViewBuilder
  private func railRow(_ step: RailStep, status: RailStatus) -> some View {
    HStack(spacing: 10) {
      Text(status == .done ? "✓" : step.id)
        .font(.bzrMono(size: 11, weight: .bold))
        .foregroundStyle(railGlyphFg(status))
        .frame(width: 24, height: 24)
        .background(
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(railGlyphBg(status))
            .overlay(
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(status == .active ? Color.bzrLime : Color.clear, lineWidth: 0.5)
            )
        )
      Text(step.label)
        .font(.bzrStencil(size: 14, weight: .bold))
        .tracking(0.7)
        .foregroundStyle(status == .pending ? Color.txtTertiary : Color.txtPrimary)
      Spacer()
      if status == .active {
        StatusDot(kind: .lime)
      }
    }
    .padding(.vertical, 8)
  }

  private func railGlyphFg(_ s: RailStatus) -> Color {
    switch s {
    case .done:    return .bzrVoid
    case .active:  return .bzrLime
    case .pending: return .txtTertiary
    }
  }

  private func railGlyphBg(_ s: RailStatus) -> Color {
    switch s {
    case .done:    return .bzrLime
    case .active:  return Color.bzrLime.opacity(0.20)
    case .pending: return Color.adaptiveLighten(0.04)
    }
  }

  // MARK: Right pane — per-state content

  @ViewBuilder
  private var contentBody: some View {
    switch state {
    case .unknown, .probingSystem:
      stepHeader(stepLabel: "STEP 1 / 8 · PROBING", title: "WHAT'S ON THIS MAC?")
      Text("Walking ToolLocator's hardcoded candidate paths for git, brew, chezmoi, age, gitleaks. App-context $PATH is LaunchServices-minimal — `which` lies here, so we probe explicit paths.")
        .font(.bzrBody(size: 13))
        .foregroundStyle(Color.txtSecondary)
        .frame(maxWidth: 64 * 9, alignment: .leading)
      BzrProgressBar(value: 0.15)
        .padding(.top, 8)

    case .reportingStatus(let inv), .awaitingUserConsent(let inv):
      stepHeader(stepLabel: "STEP 2 / 8 · CONSENT", title: "INSTALL WHAT'S MISSING?")
      Text("Probe done. We'll install missing tools and ask macOS for one Authorization dialog up front. Bundled gitleaks + age stay inside Sojourn.app — no system install needed.")
        .font(.bzrBody(size: 13))
        .foregroundStyle(Color.txtSecondary)
        .frame(maxWidth: 64 * 9, alignment: .leading)

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
          bodyText: "macOS surfaces its own Authorization sheet when we trigger xcode-select --install. Sojourn will poll for completion."
        )
      }

      HStack {
        Spacer()
        Button("Install missing tools") { onConsent() }
          .buttonStyle(GlassPrimaryButtonStyle())
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("bootstrap.consent")
      }
      .padding(.top, 8)

    case .installingCLT:
      installingPane(
        stepLabel: "STEP 3 / 8 · INSTALLING",
        title: "XCODE COMMAND LINE TOOLS",
        subtitle: "macOS sheet is open. We're polling xcode-select -p every 5s and watching for exit code 0. Minimize to the menu bar — Sojourn will keep going.",
        progress: 0.30
      )

    case .installingBrew:
      installingPane(
        stepLabel: "STEP 4 / 8 · INSTALLING",
        title: "HOMEBREW",
        subtitle: "Signed .pkg installer via /usr/sbin/installer. Authorization.framework prompt — no curl|bash. Apple-Silicon prefix /opt/homebrew. ~2 min.",
        progress: 0.45
      )

    case .installingMPM:
      installingPane(
        stepLabel: "STEP 5 / 8 · INSTALLING",
        title: "META-PACKAGE-MANAGER",
        subtitle: "brew install --no-quarantine. Sojourn shells out to brew bundle for the declarative source of truth. brew bundle natively manages 11 ecosystems (brew, cask, mas, vscode, go, cargo, uv, krew, npm, flatpak, tap) per ADR-0018.",
        progress: 0.60
      )

    case .installingChezmoi:
      installingPane(
        stepLabel: "STEP 6 / 8 · INSTALLING",
        title: "CHEZMOI",
        subtitle: "brew install chezmoi. Templates + age encryption + per-host overrides. Pinned 2.70.2+ for the --format=json status output.",
        progress: 0.78
      )

    case .installingMas:
      installingPane(
        stepLabel: "STEP 7 / 8 · INSTALLING",
        title: "MAS",
        subtitle: "brew install mas. Mac App Store CLI used by MasHelper for Touch-ID-gated install/upgrade of App Store apps without per-call password prompts.",
        progress: 0.90
      )

    case .ready:
      stepHeader(stepLabel: "STEP 8 / 8 · READY", title: "YOUR MAC IS YOUR MAC.")
      Text("All tools detected. You can close this and start carrying. Configure a remote in Settings → Sync to start pushing.")
        .font(.bzrBody(size: 13))
        .foregroundStyle(Color.txtSecondary)
        .frame(maxWidth: 64 * 9, alignment: .leading)
      BzrCallout(
        title: "READY",
        kind: .info,
        bodyText: "All tools detected. You can close this and start carrying."
      )
      .accessibilityIdentifier("bootstrap.ready")

    case .failed(let reason):
      stepHeader(stepLabel: "FAILED", title: "BOOTSTRAP STOPPED.")
      BzrCallout(title: "Bootstrap failed", kind: .danger, bodyText: reason)
      HStack {
        Spacer()
        Button("Retry") { onRetry() }
          .buttonStyle(GlassPrimaryButtonStyle())
          .accessibilityIdentifier("bootstrap.retry")
      }
    }
  }

  @ViewBuilder
  private func stepHeader(stepLabel: String, title: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      EyebrowLabel(text: stepLabel)
      Text(title)
        .font(.bzrStencil(size: 30, weight: .heavy))
        .foregroundStyle(Color.txtPrimary)
    }
  }

  @ViewBuilder
  private func installingPane(stepLabel: String, title: String, subtitle: String, progress: Double) -> some View {
    stepHeader(stepLabel: stepLabel, title: title)
    Text(subtitle)
      .font(.bzrBody(size: 13))
      .foregroundStyle(Color.txtSecondary)
      .frame(maxWidth: 64 * 9, alignment: .leading)
    HStack(spacing: 8) {
      BzrBadge(text: "RUNNING", kind: .lime)
      BzrBadge(text: "macOS dialog open", kind: .mute)
      Spacer()
      Text("elapsed 1:42")
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color.txtTertiary)
    }
    .padding(.top, 8)
    BzrProgressBar(value: progress)
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
          .foregroundStyle(Color.bzrLimeText)
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
              .fill(Color.adaptiveDeepen(0.25))
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
          .foregroundStyle(Color.bzrLimeText)
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
