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

internal struct GenerationsPane: View {
  var body: some View {
    StubView(
      paneID: "pane.generations",
      title: "Generations",
      subtitle: "Tarball-snapshot rollback (v0.2 step 6)",
      icon: "clock.arrow.circlepath",
      detail: """
      Each generation = git tag in the chezmoi source repo named
      `sojourn-gen-N` plus a tarball under
      ~/Library/Application Support/Sojourn/generations/N.tar.zst
      containing Brewfile.common, Brewfile.<host>, prefs.toml,
      machines.toml, and the chezmoi state hash.

      Rollback: `brew bundle install --cleanup --file=<snapshot>` →
      `chezmoi apply` → `defaults import`. ~85% of nix-darwin's atomic
      rollback UX without `/nix`.
      """
    )
  }
}

internal struct MacOSFeaturesPane: View {
  var body: some View {
    StubView(
      paneID: "pane.macosFeatures",
      title: "macOS Features",
      subtitle: "Touch ID, dock, Finder, hotkeys (v0.2 step 7)",
      icon: "switch.2",
      detail: """
      First-class UI over `defaults write` for the knobs nix-darwin's
      system.defaults would have wrapped:

      • Touch ID for sudo (re-apply LaunchAgent vs softwareupdate)
      • Dock: drag-to-reorder persistent-apps editor
      • Finder: ShowAllExtensions, ShowPathbar, _FXSortFoldersFirst, …
      • Trackpad / keyboard repeat (InitialKeyRepeat, KeyRepeat)
      • Screencapture location and format
      • Login window text
      • Hotkey editor for com.apple.symbolichotkeys.plist

      Each toggle is reversible from the Generations pane.
      """
    )
  }
}

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

internal struct AdvisoriesPane: View {
  var body: some View {
    StubView(
      paneID: "pane.advisories",
      title: "Advisories",
      subtitle: "brew vulns shell-out (v0.2 step 10)",
      icon: "exclamationmark.shield",
      detail: """
      ADR-0021 replaces the 92-line AdvisoryService no-op with a
      `brew vulns --brewfile <path> --cyclonedx` shell-out. Three
      freshness states:

      • fresh — cache <24h
      • stale — cache 24h–7d, last refresh failed
      • unavailable — no cache or >7d

      OSV-format JSON parser caps at 16 MB / depth 32. Cache key =
      SHA-256 of sorted Brewfile entries. Auto-tap of
      homebrew/brew-vulns requires user consent — never silent.
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
