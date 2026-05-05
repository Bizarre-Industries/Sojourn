// Sojourn — PackagesPane

import SwiftUI

struct PackagesPane: View {
  @Environment(AppStore.self) private var store
  @State private var selectedManager: String? = "brew"
  @State private var refreshingBrewfile = false
  @State private var masHelperError: MasHelperActionError?
  @State private var confirmingMasHelperRevoke = false

  var body: some View {
    HStack(spacing: 0) {
      List(managerSummaries, selection: $selectedManager) { manager in
        Label {
          VStack(alignment: .leading, spacing: 2) {
            Text(manager.name)
            Text("\(manager.count) packages · tier \(manager.tierLabel)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: manager.symbol)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
        .tag(manager.id)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(manager.name). \(manager.count) packages. Tier \(manager.tierLabel).")
      }
      .listStyle(.inset)
      .scrollContentBackground(.hidden)
      .background(Color(nsColor: .windowBackgroundColor))
      .frame(width: 280)

      Divider()

      packageDetail
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .accessibilityIdentifier("pane.packages")
    .task {
      await store.refreshBrewfile()
      await store.refreshMasHelperStatus()
    }
    .alert(masHelperError?.title ?? "Helper action failed", isPresented: masHelperErrorPresented) {
      Button("OK", role: .cancel) {
        masHelperError = nil
      }
    } message: {
      Text(masHelperError?.message ?? "")
    }
    .confirmationDialog(
      "Remove helper?",
      isPresented: $confirmingMasHelperRevoke,
      titleVisibility: .visible
    ) {
      Button("Remove Helper", role: .destructive) {
        Task {
          do {
            try await store.unregisterMasHelper()
          } catch {
            masHelperError = .revoke(error)
          }
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("App Store installs will stop using Touch ID until you register it again.")
    }
  }

  private var packageDetail: some View {
    let manager = selectedSummary
    let rows = inventoryRows(for: manager.id)
    return ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header(for: manager)

        if manager.id == "mas" {
          masHelperStatusRow
        }

        GroupBox("Summary") {
          Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
              Text("Packages").foregroundStyle(.secondary)
              Text("\(manager.count)").monospacedDigit()
            }
            GridRow {
              Text("Cooldown tier").foregroundStyle(.secondary)
              Text("Tier \(manager.tierLabel) · \(manager.cooldownWindow)")
            }
            GridRow {
              Text("Prompt").foregroundStyle(.secondary)
              Text(manager.promptLabel)
            }
            GridRow {
              Text("Install source").foregroundStyle(.secondary)
              Text(manager.source)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        inventorySection(manager: manager, rows: rows)
      }
      .padding(24)
      .frame(maxWidth: 760, alignment: .leading)
    }
  }

  private func header(for manager: PackageManagerSummary) -> some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text(manager.name)
          .font(.title2.weight(.semibold))
        Text(manager.description)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        Task { await refreshInventory() }
      } label: {
        Label(refreshingBrewfile ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
      }
      .disabled(refreshingBrewfile)
      .accessibilityIdentifier("packages.refresh")
      .accessibilityLabel("Refresh package inventory")
      .accessibilityHint("Reloads Brewfile package entries.")
    }
  }

  @ViewBuilder
  private func inventorySection(
    manager: PackageManagerSummary,
    rows: [PackageInventoryRow]
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Inventory")
          .font(.headline)
        Spacer()
        Text("\(rows.count) rows")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if store.brewfile == nil {
        ContentUnavailableView(
          "No Brewfile snapshot",
          systemImage: "doc.text.magnifyingglass",
          description: Text("Refresh runs brew bundle dump and renders the current Brewfile entries when Homebrew is available.")
        )
        .frame(maxWidth: .infinity, minHeight: 180)
      } else if rows.isEmpty {
        ContentUnavailableView(
          "No \(manager.name) entries",
          systemImage: manager.symbol,
          description: Text("This Brewfile has no entries for \(manager.source).")
        )
        .frame(maxWidth: .infinity, minHeight: 180)
      } else {
        List(rows) { row in
          inventoryRow(row)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minHeight: 220)
      }
    }
    .accessibilityIdentifier("packages.inventory")
  }

  private func inventoryRow(_ row: PackageInventoryRow) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: row.symbol)
        .foregroundStyle(.secondary)
        .frame(width: 22)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(row.packageID)
          .font(.callout.weight(.semibold))
          .textSelection(.enabled)
        Text(row.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 16)
      VStack(alignment: .trailing, spacing: 3) {
        Text(row.kindLabel)
          .font(.caption.weight(.medium))
        Text("Tier \(row.tierLabel) · \(row.cooldownWindow)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(row.promptLabel)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, 5)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(row.packageID). \(row.kindLabel). \(row.detail). Tier \(row.tierLabel). \(row.promptLabel)."
    )
  }

  private func inventoryRows(for managerID: String) -> [PackageInventoryRow] {
    PackageInventoryRow.rows(from: store.brewfile, managerID: managerID)
  }

  private func refreshInventory() async {
    refreshingBrewfile = true
    await store.refreshBrewfile(force: true)
    refreshingBrewfile = false
  }

  // MARK: - MasHelper status row

  @ViewBuilder
  private var masHelperStatusRow: some View {
    HStack(spacing: 12) {
      Image(systemName: masStatusSymbol)
        .foregroundStyle(masStatusColor)
        .frame(width: 20)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(masStatusTitle)
          .font(.callout.weight(.semibold))
        Text(masStatusSubtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      masStatusButton
    }
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    .accessibilityIdentifier("packages.mas-helper-status")
    .accessibilityLabel(masStatusAccessibilityLabel)
  }

  private var masStatusSymbol: String {
    switch store.masHelperStatus {
    case .registered:       return "checkmark.circle"
    case .requiresApproval: return "exclamationmark.circle"
    case .notRegistered:    return "circle"
    case .missing, .unknown:return "xmark.octagon"
    case .untrustedTool:    return "lock.slash"
    }
  }

  private var masStatusColor: Color {
    switch store.masHelperStatus {
    case .registered:       return .green
    case .requiresApproval: return .orange
    case .notRegistered:    return .secondary
    case .missing, .unknown, .untrustedTool:
      return .red
    }
  }

  private var masStatusTitle: String {
    switch store.masHelperStatus {
    case .registered:       return "Touch ID install helper active"
    case .requiresApproval: return "Helper needs approval"
    case .notRegistered:    return "Touch ID install helper not installed"
    case .missing:          return "Helper missing from app bundle"
    case .unknown:          return "Helper status unknown"
    case .untrustedTool:    return "App Store installs disabled"
    }
  }

  private var masStatusSubtitle: String {
    switch store.masHelperStatus {
    case .registered:
      return "App Store installs run through the privileged helper after authorization."
    case .requiresApproval:
      return "Approve the helper in System Settings > General > Login Items."
    case .notRegistered:
      return "Registering installs the helper with a one-time system prompt."
    case .missing:
      return "Reinstall Sojourn or rebuild from source."
    case .unknown:
      return "Sojourn could not read SMAppService status."
    case .untrustedTool(let reason, _):
      return "Use the App Store manually, or install a root-owned mas path and refresh. Details: \(reason)"
    }
  }

  private var masStatusAccessibilityLabel: String {
    "MasHelper status: \(masStatusTitle). \(masStatusSubtitle)"
  }

  @ViewBuilder
  private var masStatusButton: some View {
    switch store.masHelperStatus {
    case .registered, .untrustedTool(_, true):
      Button("Revoke") {
        confirmingMasHelperRevoke = true
      }
      .accessibilityIdentifier("packages.mas-helper-revoke")
      .accessibilityHint("Removes the helper after confirmation.")
    case .notRegistered, .requiresApproval:
      Button("Register") {
        Task {
          do {
            try await store.registerMasHelper()
          } catch {
            masHelperError = .register(error)
          }
        }
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("packages.mas-helper-register")
      .accessibilityHint("Registers a privileged helper for App Store installs and may show a macOS approval prompt.")
    case .missing, .unknown, .untrustedTool(_, false):
      EmptyView()
    }
  }

  // MARK: - Manager data

  private var selectedSummary: PackageManagerSummary {
    managerSummaries.first { $0.id == selectedManager } ?? managerSummaries[0]
  }

  private var managerSummaries: [PackageManagerSummary] {
    let counts = store.brewfile?.counts ?? .init()
    return [
      .init(
        id: "mas",
        name: "Mac App Store",
        symbol: "apple.logo",
        count: counts.mas,
        tier: .a,
        promptLabel: "Not required",
        source: "mas",
        description: "Reviewed App Store applications installed through mas."
      ),
      .init(
        id: "brew",
        name: "Homebrew",
        symbol: "terminal",
        count: counts.brews,
        tierLabel: "B-C",
        cooldownWindow: "7-14 days",
        promptLabel: "Depends on tap",
        source: "brew",
        description: "Homebrew formulae from the Brewfile. Third-party taps use the stricter tier."
      ),
      .init(
        id: "cargo",
        name: "Cargo",
        symbol: "shippingbox",
        count: counts.cargo,
        tier: .e,
        promptLabel: "Required before apply",
        source: "cargo",
        description: "Rust packages installed by cargo."
      ),
      .init(
        id: "cask",
        name: "Casks",
        symbol: "app.dashed",
        count: counts.casks,
        tierLabel: "C-D",
        cooldownWindow: "14-21 days",
        promptLabel: "Depends on tap",
        source: "brew cask",
        description: "GUI apps and packaged installers."
      ),
      .init(
        id: "uv",
        name: "uv / Python",
        symbol: "chevron.left.forwardslash.chevron.right",
        count: counts.uv,
        tier: .e,
        promptLabel: "Required before apply",
        source: "uv",
        description: "Python tools managed through uv."
      ),
      .init(
        id: "npm",
        name: "npm global",
        symbol: "curlybraces",
        count: counts.npm,
        tier: .e,
        promptLabel: "Required before apply",
        source: "npm",
        description: "Global npm packages with lifecycle-script risk."
      ),
      .init(
        id: "go",
        name: "Go install",
        symbol: "g.circle",
        count: counts.go,
        tier: .e,
        promptLabel: "Required before apply",
        source: "go",
        description: "Go module binaries."
      ),
      .init(
        id: "vscode",
        name: "VS Code",
        symbol: "curlybraces.square",
        count: counts.vscode,
        tier: .d,
        promptLabel: "Required before apply",
        source: "code",
        description: "VS Code extensions."
      ),
      .init(
        id: "krew",
        name: "krew",
        symbol: "k.square",
        count: counts.krew,
        tier: .e,
        promptLabel: "Required before apply",
        source: "kubectl krew",
        description: "kubectl plugin manager entries."
      ),
      .init(
        id: "flatpak",
        name: "Flatpak",
        symbol: "shippingbox.circle",
        count: counts.flatpak,
        tier: .e,
        promptLabel: "Required before apply",
        source: "flatpak",
        description: "Flatpak application entries from the Brewfile."
      ),
      .init(
        id: "tap",
        name: "Homebrew taps",
        symbol: "point.3.connected.trianglepath.dotted",
        count: counts.taps,
        tierLabel: "Reference",
        cooldownWindow: "No package cooldown",
        promptLabel: "Not applicable",
        source: "brew tap",
        description: "Additional Homebrew repositories."
      )
    ]
  }

  private var masHelperErrorPresented: Binding<Bool> {
    Binding(
      get: { masHelperError != nil },
      set: { isPresented in
        if !isPresented {
          masHelperError = nil
        }
      }
    )
  }

}
