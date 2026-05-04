// Sojourn — OnboardPane
//
// Sub-pane inside SyncPane (History / Conflicts / Onboard / Machines
// segmented picker). Surfaces inline bootstrap state for users who want
// to inspect setup progress outside the first-run sheet, plus the
// "Setup new dotfiles repo" affordance — primarily the repro-drift
// issue template copy button per v0.3 stage 8.
//
// Refs: ADR-0022 (Nix-mode rejected; flip-condition #2 tracks
// repro-drift reports filed against the user's own dotfiles repo);
// docs/process/plans/v0.3-plan.md stage 8.

import SwiftUI
import UniformTypeIdentifiers

struct OnboardPane: View {
  @Environment(AppStore.self) private var store
  @State private var showImporter = false
  @State private var lastResult: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        EyebrowLabel(text: "ONBOARD · BootstrapService · setup")
        Text("ONBOARD.")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Inline status of the bootstrap rail (full sheet auto-presents on first run) and helpers for setting up a new dotfiles repo.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        bootstrapStatusSection

        Divider()

        dotfilesSetupSection

        if let lastResult {
          Text(lastResult)
            .font(.bzrBody(size: 12))
            .foregroundStyle(Color.txtSecondary)
        }

        Spacer(minLength: 0)
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.onboard")
  }

  @ViewBuilder
  private var bootstrapStatusSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      EyebrowLabel(text: "Bootstrap state")
      HStack(spacing: 10) {
        StatusDot(kind: dotKind(for: store.bootstrap.state))
        Text(label(for: store.bootstrap.state))
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtPrimary)
      }
    }
  }

  @ViewBuilder
  private var dotfilesSetupSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      EyebrowLabel(text: "Setup new dotfiles repo")
      Text("Copy the repro-drift issue template into your dotfiles repo's `.github/ISSUE_TEMPLATE/` so future drift reports use the same structure.")
        .font(.bzrBody(size: 13))
        .foregroundStyle(Color.txtSecondary)
        .frame(maxWidth: 64 * 9, alignment: .leading)
      Button("Copy repro-drift issue template to dotfiles repo") {
        showImporter = true
      }
      .accessibilityIdentifier("onboard.copy-repro-drift")
    }
    .fileImporter(
      isPresented: $showImporter,
      allowedContentTypes: [.folder]
    ) { result in
      switch result {
      case .success(let url):
        copyTemplate(into: url)
      case .failure(let err):
        lastResult = "Picker error: \(err.localizedDescription)"
      }
    }
  }

  private func copyTemplate(into repoRoot: URL) {
    let needsScopedAccess = repoRoot.startAccessingSecurityScopedResource()
    defer {
      if needsScopedAccess { repoRoot.stopAccessingSecurityScopedResource() }
    }
    // `Resources/data` ships as a folder reference per project.yml;
    // bundle resources land under `data/` inside the .app, not at root.
    guard let src = BundledResourceLocator.reproDriftTemplateURL() else {
      lastResult = "Bundled template missing — rebuild Sojourn."
      return
    }
    let templateDir = repoRoot
      .appendingPathComponent(".github", isDirectory: true)
      .appendingPathComponent("ISSUE_TEMPLATE", isDirectory: true)
    let dst = templateDir.appendingPathComponent("repro-drift.md")
    do {
      try FileManager.default.createDirectory(
        at: templateDir,
        withIntermediateDirectories: true
      )
      let replacedExisting = FileManager.default.fileExists(atPath: dst.path)
      if replacedExisting {
        try FileManager.default.trashItem(at: dst, resultingItemURL: nil)
      }
      try FileManager.default.copyItem(at: src, to: dst)
      if replacedExisting {
        lastResult = "Template copied. Existing repro-drift.md moved to Trash. Commit the new template in your dotfiles repo."
      } else {
        lastResult = "Template copied. Commit it in your dotfiles repo to enable the issue template on GitHub."
      }
    } catch {
      lastResult = "Copy failed: \(error.localizedDescription)"
    }
  }

  private func dotKind(for state: BootstrapState) -> StatusDotKind {
    switch state {
    case .ready: return .lime
    case .failed: return .danger
    case .unknown, .probingSystem, .reportingStatus, .awaitingUserConsent:
      return .warn
    case .installingCLT, .installingBrew, .installingMPM, .installingChezmoi, .installingMas:
      return .ok
    }
  }

  private func label(for state: BootstrapState) -> String {
    switch state {
    case .unknown:                return "Unknown — probe not yet run."
    case .probingSystem:          return "Probing — locating brew, git, chezmoi, age, gitleaks, mas."
    case .reportingStatus(let inv):
      let n = inv.missing.count
      return "Reporting — \(n) tool\(n == 1 ? "" : "s") missing: \(inv.missing.joined(separator: ", "))."
    case .awaitingUserConsent:    return "Awaiting consent — open the bootstrap sheet to continue."
    case .installingCLT:          return "Installing — Xcode Command Line Tools."
    case .installingBrew:         return "Installing — Homebrew (signed .pkg)."
    case .installingMPM:          return "Installing — meta-package-manager (legacy)."
    case .installingChezmoi:      return "Installing — chezmoi via brew."
    case .installingMas:          return "Installing — mas via brew."
    case .ready:                  return "Ready — all required tools detected."
    case .failed(let reason):     return "Failed — \(reason)"
    }
  }
}
