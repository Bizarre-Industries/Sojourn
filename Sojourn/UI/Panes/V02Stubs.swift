// Sojourn — v0.2 pane stubs
//
// Placeholder views for the 4 new Pane enum cases that v0.2 introduces
// in MainWindowView (Generations, MacOSFeatures, Sync, Advisories).
// Full implementations land in:
//
//   - GenerationsPane    → step 6 (GenerationService + tarball schema)
//   - MacOSFeaturesPane  → step 7 (Touch ID, dock, Finder, hotkeys)
//   - AdvisoriesPane     → step 10 (brew vulns shell-out)
//   - SyncPane           → step 6 + step 5 (machines + history + onboard
//                          consolidation; existing MachinesPane /
//                          HistoryPane / OnboardPane remain on disk
//                          until step 4's Panes.swift split)
//
// Stubs use the same lime accent + monospace JetBrains tone as the
// rest of the v0.1 UI so the v0.2 shell looks coherent during the
// in-progress steps.
//
// Refs: docs/process/plans/v0.2-plan.md.

import SwiftUI

internal struct SyncPane: View {
  var body: some View {
    StubView(
      paneID: "pane.sync",
      title: "Sync",
      subtitle: "Push / pull / history / conflicts (v0.2 step 5+6)",
      icon: "arrow.triangle.2.circlepath",
      detail: """
      Consolidates the v0.1 History, Conflicts, and Onboard panes into
      one master surface. Top half: push/pull controls + history
      timeline. Bottom half: conflicts list (when present) + machine
      writer-lock status.

      Cooperative writer lock per ADR-0012 — pull resolves any conflict
      before push is allowed.
      """
    )
  }
}

private struct StubView: View {
  let paneID: String
  let title: String
  let subtitle: String
  let icon: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 28, weight: .medium))
          .foregroundStyle(.tint)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 22, weight: .bold))
          Text(subtitle)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
        }
      }

      Text(detail)
        .font(.system(size: 12, weight: .regular, design: .monospaced))
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        .frame(maxWidth: 720, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

      Spacer(minLength: 0)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityIdentifier(paneID)
  }
}
