// Sojourn — ContainersPane

import SwiftUI

internal struct ContainersPane: View {
  @Environment(AppStore.self) private var store
  @State private var rescanning = false
  private let onOpenPackages: (() -> Void)?

  internal init(onOpenPackages: (() -> Void)? = nil) {
    self.onOpenPackages = onOpenPackages
  }

  internal var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header

      if store.containers.runtimes.isEmpty {
        ProgressView("Probing runtimes...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if !store.containers.anyInstalled {
        ContentUnavailableView {
          Label("No container runtime installed", systemImage: "cube.box")
        } description: {
          Text(
            "Open Packages and add Docker, OrbStack, Apple container, Lima, or Colima to your Brewfile before installing."
          )
        } actions: {
          Button("Open Packages") {
            onOpenPackages?()
          }
          .disabled(onOpenPackages == nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(store.containers.runtimes) { runtime in
          runtimeRow(runtime)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
      }

      Divider()
      footer
    }
    .padding(24)
    .background(Color(nsColor: .windowBackgroundColor))
    .accessibilityIdentifier("pane.containers")
    .task {
      await store.refreshContainers(forceRescan: false)
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Containers")
          .font(.title2.weight(.semibold))
        Text("Read-only runtime detection in Sojourn priority order.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        Task {
          rescanning = true
          await store.refreshContainers(forceRescan: true)
          rescanning = false
        }
      } label: {
        Label(rescanning ? "Rescanning" : "Rescan", systemImage: "arrow.clockwise")
      }
      .disabled(rescanning)
      .accessibilityIdentifier("containers.rescan")
      .accessibilityLabel(
        rescanning ? "Rescanning container runtimes" : "Rescan container runtimes"
      )
      .accessibilityHint(
        "Rechecks installed container command-line tools without starting or stopping runtimes.")
    }
  }

  private func runtimeRow(_ status: RuntimeStatus) -> some View {
    HStack(spacing: 12) {
      Image(systemName: symbol(for: status.runtime))
        .foregroundStyle(status.installed ? Color.accentColor : Color.secondary)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 8) {
          Text(status.runtime.displayName)
            .font(.callout.weight(.semibold))
            .lineLimit(1)
          if status.runtime == store.containers.activeRuntime, status.installed {
            Label("Active", systemImage: "checkmark.circle.fill")
              .font(.caption)
              .foregroundStyle(.green)
          }
        }
        Text(detail(for: status))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
        Text(
          "Tool: \(status.runtime.toolName) \(status.runtime.versionArgs.joined(separator: " "))"
        )
        .font(.caption2.monospaced())
        .foregroundStyle(.tertiary)
        .lineLimit(1)
        .truncationMode(.middle)
      }
      .layoutPriority(1)
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        Text(status.installed ? "Installed" : "Not installed")
          .font(.caption.weight(.medium))
          .foregroundStyle(status.installed ? Color.primary : Color.secondary)
        Text(
          status.runtime == store.containers.activeRuntime ? "Priority active" : "Priority standby"
        )
        .font(.caption2)
        .foregroundStyle(status.installed ? Color.secondary : Color.gray)
      }
      .layoutPriority(0)
    }
    .padding(.vertical, 5)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(runtimeAccessibilityLabel(for: status))
  }

  private var footer: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("Last probed: \(formattedProbedAt)")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("Read-only detection. Sojourn does not start, stop, or install runtimes from this pane.")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }

  private func detail(for status: RuntimeStatus) -> String {
    if let version = status.version {
      return "Version \(version)"
    }
    if let probeError = status.probeError {
      return "Version unknown: \(probeError)"
    }
    return status.installed ? "Version unknown" : "Binary not found"
  }

  private func runtimeAccessibilityLabel(for status: RuntimeStatus) -> String {
    let tool =
      "Tool \(status.runtime.toolName) \(status.runtime.versionArgs.joined(separator: " "))."
    if status.runtime == store.containers.activeRuntime, status.installed {
      return
        "Active runtime: \(status.runtime.displayName). \(detail(for: status)). \(tool) Installed."
    }
    return
      "\(status.runtime.displayName). \(detail(for: status)). \(tool) \(status.installed ? "Installed." : "Not installed.")"
  }

  private func symbol(for runtime: ContainerRuntime) -> String {
    switch runtime {
    case .docker: return "shippingbox"
    case .orbstack: return "square.stack.3d.up"
    case .appleContainer: return "apple.terminal"
    case .lima: return "l.square"
    case .colima: return "c.square"
    }
  }

  private var formattedProbedAt: String {
    let probedAt = store.containers.probedAt
    guard probedAt != .distantPast else { return "never" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: probedAt, relativeTo: Date())
  }
}
