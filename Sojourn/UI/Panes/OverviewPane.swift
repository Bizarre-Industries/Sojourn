// Sojourn — OverviewPane

import SwiftUI

struct OverviewPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        EyebrowLabel(text: "BIZARRE / SOJOURN / v0.2 / GPL-3.0-OR-LATER · GUI OVER brew bundle × chezmoi × defaults")
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
              .foregroundStyle(Color.bzrLimeText)
          }
          Text("A native macOS app that carries your setup across machines. brew bundle manages 11 ecosystems natively (ADR-0018). chezmoi handles dotfile templating + age. defaults round-trips plists through cfprefsd. We never link GPL-2 backends — only invoke them as subprocesses with JSON/TOML output.")
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
    // Real package count from the parsed Brewfile AST (BrewfileService
    // dump). `outdated` is not yet computed for v0.2 — `brew bundle dump`
    // is a snapshot of the spec, not a diff against installed state.
    // Showing "—" until step 11 wires `brew outdated` parsing.
    let total = store.brewfile?.packageCount ?? 0
    let outdatedLabel = "—"

    return VStack(alignment: .leading, spacing: 0) {
      // Header strip.
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Image(systemName: "shippingbox.fill")
            .font(.system(size: 14))
            .foregroundStyle(Color.bzrLimeText)
          Text("PACKAGES")
            .font(.bzrStencil(size: 18, weight: .heavy))
            .foregroundStyle(Color.txtPrimary)
          Spacer()
          Text("\(total) · \(outdatedLabel) OUTDATED")
            .font(.bzrMono(size: 11, weight: .medium))
            .foregroundStyle(Color.bzrLimeText)
        }
        Text("brew bundle · 11 ECOSYSTEMS · `--cyclonedx` SBOM via brew vulns · single-pass install")
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
              .foregroundStyle(Color.bzrLimeText)
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
    let c = store.brewfile?.counts ?? .init()
    return [
      .init(tier: "A", tierKind: .tierA, label: "mas", count: "\(c.mas)", note: "auto · 0d · Apple reviews"),
      .init(tier: "B", tierKind: .tierB, label: "brew", count: "\(c.brews)", note: "7d · curated formulae"),
      .init(tier: "B", tierKind: .tierB, label: "cargo", count: "\(c.cargo)", note: "7d · crates.io"),
      .init(tier: "C", tierKind: .tierC, label: "cask", count: "\(c.casks)", note: "7d · prompt · install scripts"),
      .init(tier: "D", tierKind: .tierD, label: "uv · pip", count: "\(c.uv)", note: "7d · prompt · global interpreter"),
      .init(tier: "E", tierKind: .tierE, label: "npm global", count: "\(c.npm)", note: "14d · never silent · pre/postinstall")
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
          Text(store.chezmoi == nil ? "NOT CONFIGURED" : "TRACKED")
            .font(.bzrMono(size: 11, weight: .medium))
            .foregroundStyle(store.chezmoi == nil ? Color.txtTertiary : Color.bzrLime)
        }
        Text("chezmoi · age · per-host templates")
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
        if store.chezmoi == nil {
          Text("chezmoi not detected on PATH. Install via Settings → Bootstrap, or `brew install chezmoi`.")
            .font(.bzrBody(size: 11))
            .foregroundStyle(Color.txtSecondary)
        } else {
          Text("chezmoi available. Per-file managed list + diff render in the Sync → Onboard tab.")
            .font(.bzrBody(size: 11))
            .foregroundStyle(Color.txtSecondary)
        }
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
          Text("—")
            .font(.bzrMono(size: 11, weight: .medium))
            .foregroundStyle(Color.txtTertiary)
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

      VStack(alignment: .leading, spacing: 6) {
        Text("Per-domain plist export/import via PrefService runs from the Preferences pane. Discovery + diff land in v0.3.")
          .font(.bzrBody(size: 11))
          .foregroundStyle(Color.txtSecondary)
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
    BzrCard(eyebrow: "SYNC") {
      VStack(alignment: .leading, spacing: 12) {
        Text("EXPLICIT PUSH/PULL · ONE WRITER · gitleaks BEFORE COMMIT · TARBALL SNAPSHOT BEFORE PULL · 30D RETENTION")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
        HStack(spacing: 8) {
          Button {
            guard let sync = store.sync else { return }
            Task { await sync.pull() }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "arrow.down")
                .font(.system(size: 11, weight: .semibold))
              Text("Pull")
            }
          }
          .buttonStyle(GlassCapsuleButtonStyle())
          .disabled(store.sync == nil)

          Button {
            guard let sync = store.sync else { return }
            Task { await sync.push(message: "sojourn: sync") }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "arrow.up")
                .font(.system(size: 11, weight: .semibold))
              Text("Push")
            }
          }
          .buttonStyle(GlassPrimaryButtonStyle())
          .disabled(store.sync == nil)

          Spacer()

          if let last = store.settings.lastSyncTime {
            Text("LAST SYNC \(Self.relativeTimeFormatter.localizedString(for: last, relativeTo: Date()).uppercased())")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtTertiary)
          } else {
            Text(store.sync == nil ? "SYNC NOT CONFIGURED — SEE SETTINGS" : "NO SYNCS YET")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtTertiary)
          }
        }
      }
    }
  }

  // Formatter for the "LAST SYNC 14m ago" footer in carryMotionCard.
  private static let relativeTimeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f
  }()

  // MARK: Scheduler card

  private var schedulerCard: some View {
    BzrCard(eyebrow: "SCHEDULER · NSBackgroundActivityScheduler") {
      VStack(alignment: .leading, spacing: 6) {
        Text("Background refresh tasks (refresh-outdated 1h, refresh-advisories 6h) wire to NSBackgroundActivityScheduler in v0.3 — this card will then show next-fire timing and skip-log.")
          .font(.bzrBody(size: 11))
          .foregroundStyle(Color.txtSecondary)
      }
    }
    .frame(width: 300)
  }
}
