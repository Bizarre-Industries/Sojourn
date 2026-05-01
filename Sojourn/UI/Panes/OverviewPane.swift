// Sojourn — OverviewPane

import SwiftUI

struct OverviewPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        EyebrowLabel(text: "BIZARRE / SOJOURN / V1.0 / GPL-3.0-OR-LATER · GUI OVER mpm × chezmoi × defaults")
          .padding(.top, 8)

        // Hero — "PACKAGES. DOTFILES. PREFS."
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("PACKAGES.")
              .font(.bzrStencil(size: 38, weight: .heavy))
              .foregroundStyle(Color.txtPrimary)
          }
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("DOTFILES.")
              .font(.bzrStencil(size: 38, weight: .heavy))
              .foregroundStyle(Color.txtPrimary)
            Text("PREFS.")
              .font(.bzrStencil(size: 38, weight: .heavy))
              .foregroundStyle(Color.bzrLime)
          }
          Text("A native macOS app that carries your setup across machines. mpm fans out to 12 managers in parallel. chezmoi handles dotfile templating + age. defaults round-trips plists through cfprefsd. We never link GPL-2 backends — only invoke them as subprocesses with JSON/TOML output.")
            .font(.bzrBody(size: 13))
            .foregroundStyle(Color.txtSecondary)
            .lineSpacing(2)
            .frame(maxWidth: 64 * 8, alignment: .leading)
        }

        // Three carry surface cards — packages (large), dotfiles, prefs.
        HStack(alignment: .top, spacing: 12) {
          packagesCard
          dotfilesCard
          prefsCard
        }

        // Carry motion + scheduler.
        HStack(alignment: .top, spacing: 12) {
          carryMotionCard
          schedulerCard
        }

        // Closing callout.
        BzrCallout(
          title: "YOU ALREADY KNOW. CATCH THE STARS.",
          kind: .info,
          bodyText: "Three commands separate \"fresh Mac\" from \"your Mac.\" Sojourn handles two automatically and prompts for the third. The bench is honest — every push gitleaks-scans, every pull snapshots, every destructive op writes a tarball before touching the working tree."
        )
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.overview")
  }

  // MARK: Packages card

  private var packagesCard: some View {
    let total = store.managers.values.map { $0.packages.count }.reduce(0, +)
    let outdated = store.managers.values
      .flatMap { $0.packages }
      .filter { $0.installedVersion != nil && $0.installedVersion != ($0.latestVersion ?? "") && $0.latestVersion != nil }
      .count

    return VStack(alignment: .leading, spacing: 0) {
      // Header strip.
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Image(systemName: "shippingbox.fill")
            .font(.system(size: 14))
            .foregroundStyle(Color.bzrLime)
          Text("PACKAGES")
            .font(.bzrStencil(size: 18, weight: .heavy))
            .foregroundStyle(Color.txtPrimary)
          Spacer()
          Text("\(total) · \(outdated) OUTDATED")
            .font(.bzrMono(size: 11, weight: .medium))
            .foregroundStyle(Color.bzrLime)
        }
        Text("mpm 6.3.0 · 12 MANAGERS · `--table-format json` · 90s/call · parallel fanout")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.bzrLime.opacity(0.06))
      .overlay(
        Rectangle()
          .fill(Color.hairline)
          .frame(height: 0.5),
        alignment: .bottom
      )

      // Tier list body.
      VStack(alignment: .leading, spacing: 8) {
        ForEach(packagesTierRows) { row in
          HStack(spacing: 10) {
            BzrBadge(text: row.tier, kind: row.tierKind)
            Text(row.label)
              .font(.bzrBody(size: 12, weight: .semibold))
              .foregroundStyle(Color.txtPrimary)
              .frame(width: 90, alignment: .leading)
            Text(row.count)
              .font(.bzrMono(size: 11, weight: .medium))
              .foregroundStyle(Color.bzrLime)
              .frame(width: 30, alignment: .leading)
            Text(row.note)
              .font(.bzrBody(size: 11))
              .foregroundStyle(Color.txtSecondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        Text("↻ ADVISORY-AWARE BYPASS · OSV/GHSA HIT → SKIP COOLDOWN · DAILY REFRESH")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
          .padding(.top, 6)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous))
    .frame(minWidth: 380, idealWidth: 460)
  }

  private struct PackagesTierRow: Identifiable {
    let id = UUID()
    let tier: String
    let tierKind: BzrBadgeKind
    let label: String
    let count: String
    let note: String
  }

  private var packagesTierRows: [PackagesTierRow] {
    [
      .init(tier: "A", tierKind: .tierA, label: "mas", count: "14", note: "auto · 0d · Apple reviews"),
      .init(tier: "B", tierKind: .tierB, label: "brew", count: "87", note: "7d · curated formulae"),
      .init(tier: "B", tierKind: .tierB, label: "cargo", count: "22", note: "7d · crates.io"),
      .init(tier: "C", tierKind: .tierC, label: "cask", count: "31", note: "7d · prompt · install scripts"),
      .init(tier: "D", tierKind: .tierD, label: "pipx · pip", count: "11", note: "7d · prompt · global interpreter"),
      .init(tier: "E", tierKind: .tierE, label: "npm global", count: "9", note: "14d · never silent · pre/postinstall")
    ]
  }

  // MARK: Dotfiles card

  private var dotfilesCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Image(systemName: "doc.text")
            .font(.system(size: 14))
            .foregroundStyle(Color.txtSecondary)
          Text("DOTFILES")
            .font(.bzrStencil(size: 18, weight: .heavy))
            .foregroundStyle(Color.txtPrimary)
          Spacer()
          Text("32 · 4 DRIFT")
            .font(.bzrMono(size: 11, weight: .medium))
            .foregroundStyle(Color.bzrLime)
        }
        Text("chezmoi 2.70.2 · age · per-host templates")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(
        Rectangle().fill(Color.hairline).frame(height: 0.5),
        alignment: .bottom
      )

      VStack(alignment: .leading, spacing: 6) {
        dotfileRow(.warn, ".zshrc", "+4 −1")
        dotfileRow(.warn, ".gitconfig", "+1 −0")
        dotfileRow(.ok, ".config/nvim/init.lua", "+47 new")
        dotfileRow(.ok, ".tmux.conf", "+2 −0")
        HStack(spacing: 8) {
          BzrBadge(text: "AGE", kind: .mute)
          Text("private_dot_ssh/encrypted_id_ed25519.age")
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .padding(.top, 4)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous))
    .frame(minWidth: 240, idealWidth: 280)
  }

  @ViewBuilder
  private func dotfileRow(_ kind: StatusDotKind, _ label: String, _ delta: String) -> some View {
    HStack(spacing: 8) {
      StatusDot(kind: kind)
      Text(label)
        .font(.bzrBody(size: 11))
        .foregroundStyle(Color.txtPrimary)
      Spacer()
      Text(delta)
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color.txtTertiary)
    }
  }

  // MARK: Prefs card

  private var prefsCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Image(systemName: "slider.horizontal.3")
            .font(.system(size: 14))
            .foregroundStyle(Color.txtSecondary)
          Text("PREFS")
            .font(.bzrStencil(size: 18, weight: .heavy))
            .foregroundStyle(Color.txtPrimary)
          Spacer()
          Text("18 · 2 DRIFT")
            .font(.bzrMono(size: 11, weight: .medium))
            .foregroundStyle(Color.bzrLime)
        }
        Text("defaults export/import · plutil xml1 · cfprefsd")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(
        Rectangle().fill(Color.hairline).frame(height: 0.5),
        alignment: .bottom
      )

      VStack(alignment: .leading, spacing: 8) {
        prefRow(.success, "USER", "iTerm2, Dock, Finder, Raycast", "14")
        prefRow(.mute, "APP-SUPP", "Karabiner keymaps", "3")
        prefRow(.tierC, "FDA", "Safari, 1Password", "v2")
        prefRow(.tierE, "SYS", "loginwindow · refused", "—")
        Text("QUIT-AND-RELAUNCH ON IMPORT")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
          .padding(.top, 4)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous))
    .frame(minWidth: 240, idealWidth: 280)
  }

  @ViewBuilder
  private func prefRow(_ kind: BzrBadgeKind, _ tag: String, _ label: String, _ count: String) -> some View {
    HStack(spacing: 8) {
      BzrBadge(text: tag, kind: kind)
      Text(label)
        .font(.bzrBody(size: 11))
        .foregroundStyle(Color.txtPrimary)
        .lineLimit(1)
      Spacer()
      Text(count)
        .font(.bzrMono(size: 10))
        .foregroundStyle(count == "—" ? Color.txtTertiary : Color.bzrLime)
    }
  }

  // MARK: Carry-motion card

  private var carryMotionCard: some View {
    BzrCard(eyebrow: "THE CARRY MOTION") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          BzrBadge(text: "WORK-MBP", kind: .lime)
          Text("━━━ ↑ ━━━")
            .font(.bzrMono(size: 12))
            .foregroundStyle(Color.bzrLime)
          BzrBadge(text: "ORIGIN/MAIN", kind: .mute)
          Text("━━━ ↓ ━━━")
            .font(.bzrMono(size: 12))
            .foregroundStyle(Color.bzrLime)
          BzrBadge(text: "PERSONAL-MINI", kind: .mute)
        }
        Text("EXPLICIT PUSH/PULL · ONE WRITER · gitleaks BEFORE COMMIT · TARBALL SNAPSHOT BEFORE PULL · 30D RETENTION")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
        HStack(spacing: 8) {
          Button {
            // Pull sheet trigger — wired by SyncCoordinator in Phase B.
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "arrow.down")
                .font(.system(size: 11, weight: .semibold))
              Text("Pull")
            }
          }
          .buttonStyle(GlassCapsuleButtonStyle())

          Button {
            // Push sheet trigger — wired by SyncCoordinator in Phase B.
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "arrow.up")
                .font(.system(size: 11, weight: .semibold))
              Text("Push 3 changes")
            }
          }
          .buttonStyle(GlassPrimaryButtonStyle())

          Spacer()

          Text("LAST PUSH 2H · a3f9c2e · clean")
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
        }
      }
    }
  }

  // MARK: Scheduler card

  private var schedulerCard: some View {
    BzrCard(eyebrow: "SCHEDULER · NSBackgroundActivityScheduler") {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          StatusDot(kind: .lime)
          Text("app.bizarre.sojourn.refresh-outdated")
            .font(.bzrBody(size: 12, weight: .semibold))
            .foregroundStyle(Color.txtPrimary)
        }
        Text("1H INTERVAL · 15M TOLERANCE · QoS .utility · APP NAP-AWARE · AC-ONLY OPT")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
        BzrProgressBar(value: 0.74)
          .padding(.top, 2)
        HStack {
          Text("NEXT")
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
          Spacer()
          Text("14m")
            .font(.bzrMono(size: 11, weight: .medium))
            .foregroundStyle(Color.bzrLime)
        }
      }
    }
    .frame(width: 300)
  }
}
