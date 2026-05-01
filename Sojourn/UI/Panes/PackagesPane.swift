// Sojourn — PackagesPane

import SwiftUI

struct PackagesPane: View {
  @Environment(AppStore.self) private var store
  @State private var selectedManager: String = "brew"
  @State private var filter: String = "All"

  var body: some View {
    HStack(spacing: 0) {
      managerMidlist
      Rectangle().fill(Color.hairline).frame(width: 0.5)
      packageDetail
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("pane.packages")
  }

  // MARK: Midlist

  private struct ManagerSummary: Identifiable {
    let id: String
    let glyph: String
    let name: String
    let pkgs: Int
    let outdated: Int
    let tier: String
    let tierKind: BzrBadgeKind
    let sub: String
  }

  private var managerSummaries: [ManagerSummary] {
    [
      .init(id: "brew", glyph: "BR", name: "Homebrew", pkgs: 87, outdated: 12, tier: "B", tierKind: .tierB, sub: "formulae"),
      .init(id: "cask", glyph: "CA", name: "Cask", pkgs: 31, outdated: 4, tier: "C", tierKind: .tierC, sub: "gui apps"),
      .init(id: "mas", glyph: "MA", name: "Mac App Store", pkgs: 14, outdated: 1, tier: "A", tierKind: .tierA, sub: "mas-cli"),
      .init(id: "cargo", glyph: "CA", name: "Cargo", pkgs: 22, outdated: 0, tier: "B", tierKind: .tierB, sub: "rust"),
      .init(id: "pipx", glyph: "PI", name: "pipx", pkgs: 11, outdated: 0, tier: "D", tierKind: .tierD, sub: "python tools"),
      .init(id: "npm", glyph: "NP", name: "npm (global)", pkgs: 9, outdated: 0, tier: "E", tierKind: .tierE, sub: "pnpm n/a"),
      .init(id: "gem", glyph: "GE", name: "gem", pkgs: 6, outdated: 0, tier: "D", tierKind: .tierD, sub: "ruby"),
      .init(id: "composer", glyph: "CO", name: "composer", pkgs: 4, outdated: 0, tier: "D", tierKind: .tierD, sub: "php")
    ]
  }

  private var managerMidlist: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        Text("MANAGERS")
          .font(.bzrEyebrow)
          .tracking(1.6)
          .textCase(.uppercase)
          .foregroundStyle(Color.txtTertiary)
        Spacer()
        Text("\(managerSummaries.count)")
          .font(.bzrMono(size: 11, weight: .medium))
          .foregroundStyle(Color.bzrLime)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(managerSummaries) { mgr in
            managerRow(mgr)
          }
        }
      }
    }
    .frame(width: 280)
    .background(Color.black.opacity(0.18))
  }

  @ViewBuilder
  private func managerRow(_ mgr: ManagerSummary) -> some View {
    let selected = selectedManager == mgr.id
    Button { selectedManager = mgr.id } label: {
      HStack(spacing: 10) {
        // 2-letter glyph chip
        Text(mgr.glyph)
          .font(.bzrStencil(size: 12, weight: .bold))
          .tracking(0.5)
          .foregroundStyle(selected ? Color.bzrVoid : Color.txtPrimary)
          .frame(width: 28, height: 28)
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(selected ? Color.bzrLime : Color.white.opacity(0.06))
          )

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(mgr.name)
              .font(.bzrBody(size: 13, weight: .semibold))
              .foregroundStyle(Color.txtPrimary)
            if mgr.outdated > 0 {
              StatusDot(kind: .warn)
            }
          }
          HStack(spacing: 4) {
            Text("\(mgr.pkgs) pkg")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtTertiary)
            Text("·")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtQuaternary)
            Text(mgr.outdated > 0 ? "\(mgr.outdated) outdated" : "up to date")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtTertiary)
            Text("·")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtQuaternary)
            Text("tier \(mgr.tier)")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtTertiary)
          }
        }
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(selected ? Color.bzrLime.opacity(0.10) : Color.clear)
      .overlay(
        Rectangle()
          .fill(selected ? Color.bzrLime : Color.clear)
          .frame(width: 2),
        alignment: .leading
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: Detail

  private var packageDetail: some View {
    let mgr = managerSummaries.first { $0.id == selectedManager } ?? managerSummaries[0]
    return ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "\(mgr.name.uppercased()) · /OPT/HOMEBREW/BIN/\(mgr.id.uppercased()) · 4.4.7")
        Text("\(mgr.name.uppercased()) · \(mgr.pkgs) PACKAGES")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("\(mgr.outdated) outdated, 5 past cooldown, 7 still aging. Tier \(mgr.tier) — \(tierWindow(mgr.tier)) default. Advisory bypass active for OSV/GHSA findings.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        // Tier badges row
        HStack(spacing: 8) {
          BzrBadge(text: "TIER \(mgr.tier) · \(tierWindow(mgr.tier).uppercased()) AUTO", kind: mgr.tierKind)
          BzrBadge(text: "JSON API · 7d cache", kind: .mute)
          BzrBadge(text: "5 ELIGIBLE NOW", kind: .mute)
          Spacer()
          Text("LAST OUTDATED CHECK · 2H AGO")
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
        }

        Text("Outdated · cross-manager view")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 4)

        outdatedTable

        // Per-machine gating + streaming log
        HStack(alignment: .top, spacing: 12) {
          BzrCard(eyebrow: "PER-MACHINE GATING / packages.toml") {
            BzrCodeBlock(text: """
              [brew]
              ripgrep = "*"
              fd = "*"
              eza = "*"

              [brew.only."work-mbp"]
              docker = "*"
              slack = "*"

              [brew.exclude."personal-mini"]
              postgres@16 = "*"
              """)
          }
          BzrCard(eyebrow: "STREAMING JOB · brew outdated") {
            VStack(alignment: .leading, spacing: 0) {
              logLine("14:22:01", "$", "brew outdated --json", .secondary)
              logLine("14:22:02", "→", "warming JSON API cache", .tertiary)
              logLine("14:22:04", "✓", "87 formulae checked", .ok)
              logLine("14:22:04", "→", "12 outdated", .lime)
              logLine("14:22:05", "$", "brew bundle list --all", .secondary)
              logLine("14:22:09", "⚠", "pip: search not implemented", .warn)
              logLine("14:22:11", "✓", "aggregated 8 managers", .ok)
              logLine("14:22:11", "━", "17 outdated total", .lime)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous))
          }
          .frame(width: 320)
        }
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func tierWindow(_ tier: String) -> String {
    switch tier {
    case "A": return "0d"
    case "B", "C", "D": return "7d"
    case "E": return "14d"
    default: return "—"
    }
  }

  // MARK: Outdated table

  private struct OutdatedRow: Identifiable {
    let id = UUID()
    let pkg: String
    let from: String
    let to: String
    let mgr: String
    let tier: String
    let tierKind: BzrBadgeKind
    let cooldown: String
    let state: OutdatedState
  }

  private enum OutdatedState { case eligible, cooldown, prompt, auto }

  private var outdatedRows: [OutdatedRow] {
    [
      .init(pkg: "ripgrep", from: "14.1.1", to: "14.1.4", mgr: "brew", tier: "B", tierKind: .tierB, cooldown: "7d ✓", state: .eligible),
      .init(pkg: "fd", from: "10.2.1", to: "10.3.0", mgr: "brew", tier: "B", tierKind: .tierB, cooldown: "8d ✓", state: .eligible),
      .init(pkg: "eza", from: "0.18.24", to: "0.19.1", mgr: "brew", tier: "B", tierKind: .tierB, cooldown: "12d ✓", state: .eligible),
      .init(pkg: "zoxide", from: "0.9.6", to: "0.9.8", mgr: "brew", tier: "B", tierKind: .tierB, cooldown: "3d / 7d", state: .cooldown),
      .init(pkg: "ghostty", from: "1.0.4", to: "1.1.2", mgr: "cask", tier: "C", tierKind: .tierC, cooldown: "9d · runs script", state: .prompt),
      .init(pkg: "Raycast", from: "1.84.5", to: "1.85.1", mgr: "cask", tier: "C", tierKind: .tierC, cooldown: "5d / 7d", state: .prompt),
      .init(pkg: "1Password 7", from: "7.9.11", to: "7.10.0", mgr: "mas", tier: "A", tierKind: .tierA, cooldown: "0d · ready", state: .auto),
      .init(pkg: "typescript", from: "5.4.2", to: "5.6.3", mgr: "npm", tier: "E", tierKind: .tierE, cooldown: "21d ✓ · advisory", state: .prompt),
      .init(pkg: "mypy", from: "1.8.0", to: "1.11.2", mgr: "pipx", tier: "D", tierKind: .tierD, cooldown: "14d ✓", state: .prompt),
      .init(pkg: "cargo-watch", from: "8.4.1", to: "8.5.3", mgr: "cargo", tier: "B", tierKind: .tierB, cooldown: "11d ✓", state: .eligible)
    ]
  }

  private var outdatedTable: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 0) {
        tableHeader("Package", width: 130)
        tableHeader("Installed", width: 80)
        tableHeader("", width: 24)
        tableHeader("Latest", width: 80)
        tableHeader("Mgr", width: 60)
        tableHeader("Tier", width: 60)
        tableHeader("Cooldown", width: 130)
        tableHeader("", width: 80)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.white.opacity(0.02))
      .overlay(
        Rectangle().fill(Color.hairline).frame(height: 0.5),
        alignment: .bottom
      )

      ForEach(outdatedRows) { row in
        HStack(spacing: 0) {
          tableCell(row.pkg, width: 130, weight: .semibold)
          tableCell(row.from, width: 80, color: .txtSecondary)
          tableCell("→", width: 24, color: .txtTertiary)
          tableCell(row.to, width: 80, color: .bzrLime, weight: .semibold)
          tableCell(row.mgr, width: 60, color: .txtTertiary)
          HStack { BzrBadge(text: row.tier, kind: row.tierKind); Spacer() }
            .frame(width: 60).padding(.horizontal, 12).padding(.vertical, 7)
          tableCell(row.cooldown, width: 130, color: .txtTertiary)
          HStack { stateBadge(row.state); Spacer() }
            .frame(width: 80).padding(.horizontal, 12).padding(.vertical, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
          Rectangle().fill(Color.hairlineInner).frame(height: 0.5),
          alignment: .bottom
        )
      }
    }
    .background(Color.black.opacity(0.20))
    .clipShape(RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
        .stroke(Color.hairline, lineWidth: 0.5)
    )
  }

  @ViewBuilder
  private func tableHeader(_ text: String, width: CGFloat) -> some View {
    Text(text)
      .font(.bzrMono(size: 9, weight: .semibold))
      .tracking(1.6)
      .textCase(.uppercase)
      .foregroundStyle(Color.txtTertiary)
      .frame(width: width, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
  }

  @ViewBuilder
  private func tableCell(_ text: String, width: CGFloat, color: Color = .txtPrimary, weight: Font.Weight = .medium) -> some View {
    Text(text)
      .font(.bzrMono(size: 11, weight: weight))
      .foregroundStyle(color)
      .frame(width: width, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
  }

  @ViewBuilder
  private func stateBadge(_ state: OutdatedState) -> some View {
    switch state {
    case .eligible: BzrBadge(text: "READY", kind: .success)
    case .cooldown: BzrBadge(text: "AGING", kind: .mute)
    case .prompt:   BzrBadge(text: "PROMPT", kind: .tierC)
    case .auto:     BzrBadge(text: "AUTO", kind: .lime)
    }
  }

  // MARK: Log line atom

  private enum LogTone { case secondary, tertiary, ok, warn, lime }

  @ViewBuilder
  private func logLine(_ ts: String, _ glyph: String, _ msg: String, _ tone: LogTone) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(ts)
        .font(.bzrMono(size: 11))
        .foregroundStyle(Color.txtTertiary)
      Text(glyph)
        .font(.bzrMono(size: 11, weight: .bold))
        .foregroundStyle(toneColor(tone))
      Text(msg)
        .font(.bzrMono(size: 11))
        .foregroundStyle(Color(red: 220 / 255, green: 225 / 255, blue: 210 / 255).opacity(0.85))
    }
    .padding(.vertical, 2)
  }

  private func toneColor(_ t: LogTone) -> Color {
    switch t {
    case .secondary: return .txtSecondary
    case .tertiary:  return .txtTertiary
    case .ok:        return .bzrSuccess
    case .warn:      return .bzrWarn
    case .lime:      return .bzrLime
    }
  }
}
