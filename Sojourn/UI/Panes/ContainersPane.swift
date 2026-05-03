// Sojourn — ContainersPane (v0.3, ADR-0023)
//
// Read-only display of installed container runtimes in priority
// order: Docker Desktop > OrbStack > Apple `container` > Lima >
// Colima. The first installed runtime carries the "active runtime"
// badge. Empty state surfaces a single CTA pointing at PackagesPane.
//
// v0.3 scope is detection + display only. Write actions (start/stop
// daemon, run container) are explicitly deferred to v0.4 per ADR-0023
// "Negative consequences."
//
// Refs: docs/decisions/0023-containers-panel-detection.md;
//       docs/process/plans/v0.3-plan.md stage 2;
//       .claude/council-logs/2026-05-03-v0.3-adr-batch.md.

import SwiftUI

internal struct ContainersPane: View {
  @Environment(AppStore.self) private var store
  @State private var rescanning: Bool = false

  internal var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "RUNTIMES",
        title: "Containers",
        subtitle: "Read-only detection of Docker, OrbStack, Apple container, Lima, Colima."
      )
    ) {
      content
    }
    .accessibilityIdentifier("pane.containers")
    .task {
      await store.refreshContainers(forceRescan: false)
    }
  }

  @ViewBuilder
  private var content: some View {
    if store.containers.runtimes.isEmpty {
      // Pre-first-probe state. Task above will populate it shortly.
      ProgressView("Probing runtimes…")
        .padding(.top, 16)
    } else if !store.containers.anyInstalled {
      emptyState
    } else {
      runtimeList
      if let probedAt = formattedProbedAt {
        HStack {
          Spacer()
          Text("Last probed \(probedAt)")
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
        }
      }
    }
    rescanButton
  }

  // MARK: - Empty state

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("No container runtime installed")
        .font(.bzrBody(size: 14, weight: .semibold))
        .foregroundStyle(Color.txtPrimary)
      Text("Add a runtime to your Brewfile and install it from the Packages pane. Common picks: \"docker\" (cask), \"orbstack\" (cask), \"lima\", \"colima\".")
        .font(.bzrBody(size: 13))
        .foregroundStyle(Color.txtSecondary)
        .frame(maxWidth: 64 * 9, alignment: .leading)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.white.opacity(0.04))
    )
  }

  // MARK: - Runtime list

  private var runtimeList: some View {
    let active = store.containers.activeRuntime
    return LazyVStack(alignment: .leading, spacing: 8) {
      ForEach(store.containers.runtimes) { status in
        runtimeRow(status, isActive: status.runtime == active && status.installed)
      }
    }
  }

  @ViewBuilder
  private func runtimeRow(_ status: RuntimeStatus, isActive: Bool) -> some View {
    let installed = status.installed
    HStack(spacing: 12) {
      // Glyph chip — first 2 letters of display name.
      Text(glyph(for: status.runtime))
        .font(.bzrStencil(size: 12, weight: .bold))
        .tracking(0.5)
        .foregroundStyle(installed ? Color.bzrVoid : Color.txtTertiary)
        .frame(width: 32, height: 32)
        .background(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(installed ? Color.bzrLime : Color.white.opacity(0.06))
        )

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(status.runtime.displayName)
            .font(.bzrBody(size: 13, weight: .semibold))
            .foregroundStyle(Color.txtPrimary)
          if isActive {
            activeBadge
          }
          if !installed {
            StatusDot(kind: .warn)
          }
        }
        secondaryLine(for: status)
      }
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(installed ? Color.white.opacity(0.05) : Color.clear)
    )
  }

  /// Active-runtime badge — visual + accessibility label distinct
  /// from color (per council 2026-05-03 amendment to ADR-0023).
  private var activeBadge: some View {
    Text("ACTIVE")
      .font(.bzrMono(size: 9, weight: .bold))
      .tracking(1.0)
      .foregroundStyle(Color.bzrVoid)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: 3, style: .continuous)
          .fill(Color.bzrLime)
      )
      .accessibilityLabel("Active runtime")
  }

  @ViewBuilder
  private func secondaryLine(for status: RuntimeStatus) -> some View {
    HStack(spacing: 6) {
      if !status.installed {
        Text("not installed")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      } else if let v = status.version {
        Text("v\(v)")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtSecondary)
      } else if let err = status.probeError {
        Text("version unknown — \(err)")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
          .lineLimit(1)
      } else {
        Text("version unknown")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
    }
  }

  // MARK: - Rescan

  private var rescanButton: some View {
    HStack {
      Spacer()
      Button {
        Task {
          rescanning = true
          await store.refreshContainers(forceRescan: true)
          rescanning = false
        }
      } label: {
        HStack(spacing: 6) {
          if rescanning {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
          Text("Rescan")
        }
        .font(.bzrBody(size: 12, weight: .medium))
      }
      .disabled(rescanning)
      .buttonStyle(.bordered)
      .controlSize(.small)
      .accessibilityIdentifier("containers.rescan")
    }
    .padding(.top, 8)
  }

  // MARK: - Helpers

  private func glyph(for runtime: ContainerRuntime) -> String {
    switch runtime {
    case .docker:         return "DK"
    case .orbstack:       return "OB"
    case .appleContainer: return "AC"
    case .lima:           return "LM"
    case .colima:         return "CL"
    }
  }

  private var formattedProbedAt: String? {
    let probedAt = store.containers.probedAt
    if probedAt == .distantPast { return nil }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: probedAt, relativeTo: Date())
  }
}
