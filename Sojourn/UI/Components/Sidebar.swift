// Sojourn — Liquid Glass sidebar.
//
// Translation of `chrome.jsx` Sidebar (lines 35-66 of the design bundle).
// Carry / Sync / Hygiene / App grouping in that order, matching chat 2's
// "Carry is the lead" decision.

import SwiftUI

internal enum SidebarSection: String, CaseIterable, Identifiable {
  case carry = "Carry"
  case sync = "Sync"
  case hygiene = "Hygiene"
  case app = "App"
  internal var id: String { rawValue }
}

internal struct SidebarEntry: Identifiable, Hashable {
  let id: String
  let label: String
  let icon: String
  let count: Int?
  let dotKind: StatusDotKind?
  let section: SidebarSection

  init(
    id: String,
    label: String,
    icon: String,
    section: SidebarSection,
    count: Int? = nil,
    dotKind: StatusDotKind? = nil
  ) {
    self.id = id
    self.label = label
    self.icon = icon
    self.section = section
    self.count = count
    self.dotKind = dotKind
  }
}

/// Carry-first ordering per `chrome.jsx`. Stage 2 ships static counts;
/// Stage 3 binds counts to `AppStore` projections.
internal enum SojournSidebarMenu {
  static let entries: [SidebarEntry] = [
    .init(id: "overview",    label: "Overview",    icon: "rocket",                    section: .carry),
    .init(id: "packages",    label: "Packages",    icon: "shippingbox",                section: .carry),
    .init(id: "dotfiles",    label: "Dotfiles",    icon: "doc.text",                   section: .carry),
    .init(id: "preferences", label: "Preferences", icon: "slider.horizontal.3",        section: .carry),

    .init(id: "machines",    label: "Machines",    icon: "laptopcomputer.and.iphone",  section: .sync),
    .init(id: "history",     label: "History",     icon: "clock.arrow.circlepath",     section: .sync),
    .init(id: "conflicts",   label: "Conflicts",   icon: "arrow.triangle.branch",      section: .sync),
    .init(id: "onboard",     label: "Onboard Mac", icon: "plus.rectangle.on.folder",   section: .sync),

    .init(id: "secrets",     label: "Secrets",     icon: "lock.shield",                section: .hygiene),
    .init(id: "cleanup",     label: "Cleanup",     icon: "trash",                      section: .hygiene),

    .init(id: "diagnostics", label: "Diagnostics", icon: "waveform.path.ecg",          section: .app),
    .init(id: "settings",    label: "Settings",    icon: "gear",                       section: .app),
  ]
}

internal struct GlassSidebarRow: View {
  let entry: SidebarEntry
  let selected: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 9) {
        Image(systemName: entry.icon)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(selected ? Color.bzrLime : Color.txtSecondary)
          .frame(width: 16, height: 16)

        Text(entry.label)
          .font(.bzrBody(size: 13, weight: .medium))
          .foregroundStyle(Color.txtPrimary)

        Spacer()

        if let dotKind = entry.dotKind {
          StatusDot(kind: dotKind)
        } else if let count = entry.count {
          Text("\(count)")
            .font(.bzrMono(size: 10, weight: .medium))
            .foregroundStyle(selected ? Color.bzrLime : Color.txtTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
              Capsule()
                .fill(selected ? Color.bzrLime.opacity(0.18) : Color.white.opacity(0.06))
            )
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(selected ? Color.sidebarSel : Color.clear)
          .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .stroke(selected ? Color.sidebarSelBord : Color.clear, lineWidth: 0.5)
          )
      )
      .accessibilityIdentifier("sidebar.\(entry.id)")
    }
    .buttonStyle(.plain)
  }
}

internal struct LiquidGlassSidebar: View {
  @Binding var selection: String
  let machineName: String
  let machineRole: String
  let machineActivity: String
  let machineSha: String?

  var body: some View {
    let grouped: [(SidebarSection, [SidebarEntry])] = SidebarSection.allCases.map { section in
      (section, SojournSidebarMenu.entries.filter { $0.section == section })
    }

    VStack(spacing: 2) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          ForEach(grouped, id: \.0.id) { section, items in
            Text(section.rawValue)
              .font(.bzrMono(size: 10, weight: .semibold))
              .tracking(1.6)
              .textCase(.uppercase)
              .foregroundStyle(Color.txtTertiary)
              .padding(.horizontal, 10)
              .padding(.top, section == .carry ? 6 : 14)
              .padding(.bottom, 6)
            ForEach(items) { entry in
              GlassSidebarRow(
                entry: entry,
                selected: selection == entry.id,
                onSelect: { selection = entry.id }
              )
            }
          }
        }
      }

      Spacer(minLength: 0)

      MachineFooterCard(
        name: machineName,
        role: machineRole,
        lastActivity: machineActivity,
        sha: machineSha
      )
      .padding(8)
    }
    .padding(.horizontal, 8)
    .padding(.top, 8)
    .frame(width: BzrSpacing.sidebarWidth)
    .background(
      Color.glassSidebar
        .overlay(
          Rectangle()
            .frame(width: 0.5)
            .foregroundStyle(Color.hairline),
          alignment: .trailing
        )
    )
  }
}
