// Sojourn — MachinesPane

import SwiftUI

struct MachinesPane: View {
  @Environment(AppStore.self) private var store

  private static let relativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f
  }()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        let machines = store.settings.machines
        EyebrowLabel(text: "\(machines.count) MACHINE\(machines.count == 1 ? "" : "S") · COOPERATIVE LOCK")
          .padding(.top, 8)
        Text("YOUR FLEET")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("One active writer at a time. Pull before push. The lock is a hint git doesn't enforce — it catches the 95% case of a forgotten pull.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        if machines.isEmpty {
          BzrCard(eyebrow: "FLEET") {
            VStack(alignment: .leading, spacing: 6) {
              Text("No machines registered yet")
                .font(.bzrBody(size: 13, weight: .semibold))
                .foregroundStyle(Color.txtPrimary)
              Text("Each Mac running Sojourn registers itself in `.sojourn/machines/<hostname>.toml` on first push. After your first sync from a second machine, you'll see both listed here.")
                .font(.bzrBody(size: 12))
                .foregroundStyle(Color.txtSecondary)
            }
          }
        } else {
          let cols = [
            GridItem(.flexible(minimum: 320), spacing: 12),
            GridItem(.flexible(minimum: 320), spacing: 12),
            GridItem(.flexible(minimum: 320), spacing: 12)
          ]
          LazyVGrid(columns: cols, spacing: 12) {
            ForEach(machines) { m in
              machineCard(m)
            }
          }
        }
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.machines")
  }

  @ViewBuilder
  private func machineCard(_ m: MachineMetadata) -> some View {
    let isThisMac = m.hostname == MachineMetadata.currentHostname()
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          StatusDot(kind: isThisMac ? .lime : .ok)
          Text(m.hostname.uppercased())
            .font(.bzrStencil(size: 18, weight: .heavy))
            .tracking(1.6)
            .foregroundStyle(Color.txtPrimary)
          Spacer()
          if isThisMac {
            BzrBadge(text: "THIS MAC", kind: .lime)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(isThisMac ? Color.bzrLime.opacity(0.10) : Color.adaptiveLighten(0.02))
      .overlay(
        Rectangle()
          .fill(isThisMac ? Color.bzrLime.opacity(0.30) : Color.hairline)
          .frame(height: 0.5),
        alignment: .bottom
      )

      VStack(alignment: .leading, spacing: 6) {
        machineRow("First seen", Self.relativeFormatter.localizedString(for: m.firstSeenAt, relativeTo: Date()))
        machineRow("Last seen", Self.relativeFormatter.localizedString(for: m.lastSeenAt, relativeTo: Date()))
        machineRow("Overrides", "\(m.overrides.count)", lime: !m.overrides.isEmpty)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous))
  }

  @ViewBuilder
  private func machineRow(_ label: String, _ value: String, lime: Bool = false) -> some View {
    HStack {
      Text(label)
        .font(.bzrBody(size: 12))
        .foregroundStyle(Color.txtTertiary)
        .frame(width: 100, alignment: .leading)
      if lime {
        Text(value)
          .font(.bzrMono(size: 12, weight: .semibold))
          .foregroundStyle(Color.bzrLimeText)
      } else {
        Text(value)
          .font(.bzrBody(size: 12))
          .foregroundStyle(Color.txtPrimary)
      }
      Spacer()
    }
  }
}
