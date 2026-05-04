// Sojourn — PackagesPane

import SwiftUI

struct PackagesPane: View {
  @Environment(AppStore.self) private var store
  @State private var selectedManager: String = "brew"
  @State private var filter: String = "All"

  var body: some View {
    VStack(spacing: 0) {
      if selectedManager == "mas" {
        masHelperStatusRow
        Rectangle().fill(Color.hairline).frame(height: 0.5)
      }
      HStack(spacing: 0) {
        managerMidlist
        Rectangle().fill(Color.hairline).frame(width: 0.5)
        packageDetail
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("pane.packages")
    .task {
      await store.refreshMasHelperStatus()
    }
  }

  // MARK: MasHelper status row (ADR-0024)

  /// Per ADR-0024 amendment "Helper authorization status surface": a
  /// row showing whether the privileged Touch-ID install helper is
  /// active, plus a Register / Revoke control. Visible only when the
  /// "mas" manager is selected so it sits in context.
  @ViewBuilder
  private var masHelperStatusRow: some View {
    HStack(spacing: 12) {
      StatusDot(kind: masDotKind)
      VStack(alignment: .leading, spacing: 2) {
        Text(masStatusTitle)
          .font(.bzrBody(size: 13, weight: .semibold))
          .foregroundStyle(Color.txtPrimary)
        Text(masStatusSubtitle)
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
          .lineLimit(1)
      }
      Spacer()
      masStatusButton
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(Color.white.opacity(0.04))
    .accessibilityIdentifier("packages.mas-helper-status")
    .accessibilityLabel(masStatusAccessibilityLabel)
  }

  private var masDotKind: StatusDotKind {
    switch store.masHelperStatus {
    case .registered:        return .lime
    case .requiresApproval:  return .warn
    case .notRegistered:     return .ok
    case .missing, .unknown: return .danger
    }
  }

  private var masStatusTitle: String {
    switch store.masHelperStatus {
    case .registered:       return "Touch-ID install helper active"
    case .requiresApproval: return "Helper needs your approval"
    case .notRegistered:    return "Touch-ID install helper not yet installed"
    case .missing:          return "Helper missing from app bundle"
    case .unknown:          return "Helper status unknown"
    }
  }

  private var masStatusSubtitle: String {
    switch store.masHelperStatus {
    case .registered:
      return "App Store installs run silently after first authorization"
    case .requiresApproval:
      return "Open System Settings → General → Login Items"
    case .notRegistered:
      return "Click Register to install (one-time admin prompt)"
    case .missing:
      return "Reinstall Sojourn or rebuild from source"
    case .unknown:
      return "Could not read SMAppService status"
    }
  }

  private var masStatusAccessibilityLabel: String {
    "MasHelper status: \(masStatusTitle). \(masStatusSubtitle)"
  }

  @ViewBuilder
  private var masStatusButton: some View {
    switch store.masHelperStatus {
    case .registered:
      Button("Revoke") {
        Task {
          try? await store.unregisterMasHelper()
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .accessibilityIdentifier("packages.mas-helper-revoke")
    case .notRegistered, .requiresApproval:
      Button("Register") {
        Task {
          try? await store.registerMasHelper()
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .accessibilityIdentifier("packages.mas-helper-register")
    case .missing, .unknown:
      EmptyView()
    }
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

  // Real package counts from `brew bundle dump` (BrewfileAST.counts).
  // Outdated count is 0 for v0.2 — `brew bundle dump` is a snapshot of
  // the spec, not a diff against installed state. Step 11 (in v0.3) will
  // wire `brew outdated --json` parsing for the per-manager outdated #s.
  private var managerSummaries: [ManagerSummary] {
    let c = store.brewfile?.counts ?? .init()
    return [
      .init(id: "mas",     glyph: "MA", name: "Mac App Store", pkgs: c.mas,     outdated: 0, tier: "A", tierKind: .tierA, sub: "mas-cli"),
      .init(id: "brew",    glyph: "BR", name: "Homebrew",      pkgs: c.brews,   outdated: 0, tier: "B", tierKind: .tierB, sub: "formulae"),
      .init(id: "cargo",   glyph: "CA", name: "Cargo",         pkgs: c.cargo,   outdated: 0, tier: "B", tierKind: .tierB, sub: "rust"),
      .init(id: "cask",    glyph: "CK", name: "Cask",          pkgs: c.casks,   outdated: 0, tier: "C", tierKind: .tierC, sub: "gui apps"),
      .init(id: "uv",      glyph: "UV", name: "uv (Python)",   pkgs: c.uv,      outdated: 0, tier: "D", tierKind: .tierD, sub: "pep-723"),
      .init(id: "npm",     glyph: "NP", name: "npm (global)",  pkgs: c.npm,     outdated: 0, tier: "E", tierKind: .tierE, sub: "lifecycle"),
      .init(id: "go",      glyph: "GO", name: "go install",    pkgs: c.go,      outdated: 0, tier: "B", tierKind: .tierB, sub: "modules"),
      .init(id: "vscode",  glyph: "VS", name: "VS Code",       pkgs: c.vscode,  outdated: 0, tier: "C", tierKind: .tierC, sub: "extensions"),
      .init(id: "krew",    glyph: "KR", name: "krew (kubectl)",pkgs: c.krew,    outdated: 0, tier: "C", tierKind: .tierC, sub: "plugins"),
      .init(id: "tap",     glyph: "TP", name: "Homebrew taps", pkgs: c.taps,    outdated: 0, tier: "B", tierKind: .tierB, sub: "extra repos")
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
          .foregroundStyle(Color.bzrLimeText)
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
        EyebrowLabel(text: "PACKAGES · \(mgr.name.uppercased()) · TIER \(mgr.tier)")
        Text("\(mgr.name.uppercased()) · \(mgr.pkgs) PACKAGES")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Tier \(mgr.tier) — \(tierWindow(mgr.tier)) cooldown. \(mgr.sub).")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .fixedSize(horizontal: false, vertical: true)

        Text("Outdated · cross-manager view")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 4)

        outdatedTable
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

  // The outdated table is empty in v0.2 — `brew outdated --json` parsing
  // lands in v0.3 (step 11). Until then we honestly show 0 rows + an
  // empty-state message rather than fake demo entries.
  private var outdatedRows: [OutdatedRow] { [] }

  private var outdatedTable: some View {
    Group {
      if outdatedRows.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("No outdated check yet")
            .font(.bzrBody(size: 13, weight: .semibold))
            .foregroundStyle(Color.txtPrimary)
          Text("`brew outdated --json` parsing lands in v0.3. Until then this pane shows the package counts from `brew bundle dump` (left rail) but cannot diff installed vs latest.")
            .font(.bzrMono(size: 11))
            .foregroundStyle(Color.txtTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveDeepen(0.20))
        .clipShape(RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
            .stroke(Color.hairline, lineWidth: 0.5)
        )
      } else {
        // Real outdated table only renders when there are rows. The
        // 8 fixed-width columns total ~644pt; we wrap in a horizontal
        // ScrollView so narrow windows scroll instead of clipping.
        ScrollView(.horizontal, showsIndicators: true) {
          VStack(spacing: 0) {
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
            .background(Color.adaptiveLighten(0.02))
            .overlay(
              Rectangle().fill(Color.hairline).frame(height: 0.5),
              alignment: .bottom
            )

            ForEach(outdatedRows) { row in
              HStack(spacing: 0) {
                tableCell(row.pkg, width: 130, weight: .semibold)
                tableCell(row.from, width: 80, color: .txtSecondary)
                tableCell("→", width: 24, color: .txtTertiary)
                tableCell(row.to, width: 80, color: .bzrLimeText, weight: .semibold)
                tableCell(row.mgr, width: 60, color: .txtTertiary)
                HStack { BzrBadge(text: row.tier, kind: row.tierKind); Spacer() }
                  .frame(width: 60).padding(.horizontal, 12).padding(.vertical, 7)
                tableCell(row.cooldown, width: 130, color: .txtTertiary)
                HStack { stateBadge(row.state); Spacer() }
                  .frame(width: 80).padding(.horizontal, 12).padding(.vertical, 7)
              }
              .overlay(
                Rectangle().fill(Color.hairlineInner).frame(height: 0.5),
                alignment: .bottom
              )
            }
          }
        }
        .background(Color.adaptiveDeepen(0.20))
        .clipShape(RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
            .stroke(Color.hairline, lineWidth: 0.5)
        )
      }
    }
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
