// Sojourn — Panes
//
// Twelve detail panes hang off the main window's Liquid Glass shell.
// Each pane reads @Environment(AppStore.self) for live state. Stage 3
// fills empty panes with the design's full content; Stage 2 establishes
// stubs so the chrome compiles end-to-end.
//
// See docs/reference/architecture.md §11.

import SwiftUI

// MARK: - Carry · Overview (matches carry.jsx CarryOverviewScreen)

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
      .init(tier: "A", tierKind: .tierA, label: "mas",        count: "14", note: "auto · 0d · Apple reviews"),
      .init(tier: "B", tierKind: .tierB, label: "brew",       count: "87", note: "7d · curated formulae"),
      .init(tier: "B", tierKind: .tierB, label: "cargo",      count: "22", note: "7d · crates.io"),
      .init(tier: "C", tierKind: .tierC, label: "cask",       count: "31", note: "7d · prompt · install scripts"),
      .init(tier: "D", tierKind: .tierD, label: "pipx · pip", count: "11", note: "7d · prompt · global interpreter"),
      .init(tier: "E", tierKind: .tierE, label: "npm global", count: "9",  note: "14d · never silent · pre/postinstall")
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
        dotfileRow(.warn, ".zshrc",                        "+4 −1")
        dotfileRow(.warn, ".gitconfig",                    "+1 −0")
        dotfileRow(.ok,   ".config/nvim/init.lua",         "+47 new")
        dotfileRow(.ok,   ".tmux.conf",                    "+2 −0")
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
        prefRow(.success, "USER",     "iTerm2, Dock, Finder, Raycast", "14")
        prefRow(.mute,    "APP-SUPP", "Karabiner keymaps",             "3")
        prefRow(.tierC,   "FDA",      "Safari, 1Password",             "v2")
        prefRow(.tierE,   "SYS",      "loginwindow · refused",         "—")
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

// MARK: - Sync · Conflicts (matches extras.jsx ConflictsScreen)

struct ConflictsPane: View {
  private struct Shape: Identifiable {
    let id: String
    let title: String
    let context: String
    let resolution: String
  }

  private var shapes: [Shape] {
    [
      .init(id: "1", title: "TEXT EDIT",         context: ".zshrc edited on both Macs",            resolution: "Keep local · Keep remote · Manual merge"),
      .init(id: "2", title: "PACKAGES.TOML",     context: "mpm install/remove diverged",           resolution: "Merge per-manager (grouped UI)"),
      .init(id: "3", title: "CHEZMOI TEMPLATE",  context: "dot_gitconfig.tmpl conditional clash",  resolution: "Always surfaces · cannot auto-merge Go templates"),
      .init(id: "4", title: "PLIST",             context: "iterm2 same key, different values",     resolution: "Keyed diff · per-key pick"),
      .init(id: "5", title: "RENAME × EDIT",     context: ".tmux.conf renamed + edited",           resolution: "User picks final path · git rename hint"),
      .init(id: "6", title: "DELETE × EDIT",     context: "chezmoi forget vs continued edit",      resolution: "Default: keep edit · explicit override")
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "CONFLICTS / SHAPES 1–6 / kind == .textEdit | .packagesToml | .chezmoiTemplate | .plist | .rename | .delete")
          .padding(.top, 8)
        Text("SIX SHAPES, ONE BENCH.")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Pull surfaces every conflict shape with kept ancestor + local + remote in memory. Snapshot is written before any working-tree mutation. We never auto-merge text dotfiles or Go templates.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        // Shape grid (2 columns)
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        LazyVGrid(columns: cols, spacing: 12) {
          ForEach(shapes) { shape in
            shapeCard(shape)
          }
        }
        .padding(.top, 6)

        Text("Snapshot guarantee")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 6)

        BzrCodeBlock(text: """
          ~/Library/Application Support/Sojourn/backups/2026-04-28T14-30-sync.pull/
            ├── packages.toml.before
            ├── dotfiles.tar
            ├── preferences/com.googlecode.iterm2.plist.before
            └── meta.json    // machine, op, git_head, ts

          RETENTION 30D · BackupsDirectory.gc() runs on app launch
          """)
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.conflicts")
  }

  @ViewBuilder
  private func shapeCard(_ s: Shape) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        BzrBadge(text: "SHAPE \(s.id)", kind: .tierC)
        Text(s.title)
          .font(.bzrStencil(size: 14, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Spacer()
      }
      Text(s.context)
        .font(.bzrBody(size: 11))
        .foregroundStyle(Color.txtSecondary)
      Text(s.resolution)
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color.bzrLime)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )
    )
  }
}

// MARK: - First-run · Onboard new machine (matches extras.jsx OnboardScreen)

struct OnboardPane: View {
  private struct Step: Identifiable {
    let id: String
    let label: String
    let detail: String
    let state: State

    enum State { case done, active, pending }
  }

  private var steps: [Step] {
    [
      .init(id: "1", label: "PROBE",        detail: "Found brew, mpm, chezmoi, git, age",         state: .done),
      .init(id: "2", label: "REMOTE",       detail: "git@github.com:you/my-mac.git · clone ok",   state: .done),
      .init(id: "3", label: "MACHINE ID",   detail: "mini-home.local · 8d2a-... · stored",        state: .done),
      .init(id: "4", label: "AGE IDENTITY", detail: "Generated · public recipient ready to share", state: .active),
      .init(id: "5", label: "WRITER ADDS",  detail: "Old Mac re-encrypts on next push",           state: .pending),
      .init(id: "6", label: "PULL",         detail: "mpm restore + chezmoi apply + defaults import", state: .pending),
      .init(id: "7", label: "READY",        detail: "Reader joined fleet",                        state: .pending)
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "WORK-MBP IS WRITER · NEW MACHINE WILL JOIN AS READER")
          .padding(.top, 8)
        Text("NEW MAC, OLD CONFIG.")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Sojourn generates the local age identity, prints its public recipient, and walks you through adding it to the repo so the previous Mac re-encrypts on next push. v1 keeps one writer at a time — multi-recipient is a v2 feature, but adding readers works today.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        // Remote + age cards.
        HStack(alignment: .top, spacing: 12) {
          BzrCard(eyebrow: "REMOTE · BYO IS DEFAULT") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("git@github.com:you/my-mac.git", text: .constant("git@github.com:you/my-mac.git"))
                .textFieldStyle(.plain)
                .font(.bzrMono(size: 12))
                .foregroundStyle(Color.txtPrimary)
                .padding(8)
                .background(Color.black.opacity(0.25))
                .overlay(
                  RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 0.5)
                )
              HStack(spacing: 8) {
                BzrBadge(text: "REACHABLE", kind: .success)
                BzrBadge(text: "SSH · git-credential-osxkeychain", kind: .mute)
                Spacer()
                Text("FETCH 142ms")
                  .font(.bzrMono(size: 10))
                  .foregroundStyle(Color.txtTertiary)
              }
              Rectangle().fill(Color.hairline).frame(height: 0.5)
              HStack(spacing: 8) {
                BzrBadge(text: "OR", kind: .mute)
                Text("Sign in with GitHub")
                  .font(.bzrBody(size: 11))
                  .foregroundStyle(Color.txtPrimary)
                Spacer()
                Button {} label: {
                  HStack(spacing: 4) { Image(systemName: "arrow.triangle.branch").font(.system(size: 11)); Text("Device flow") }
                }
                .buttonStyle(GlassCapsuleButtonStyle())
              }
              Text("CLIENT_ID ONLY · NO SECRETS EMBEDDED · KEYCHAIN-STORED TOKEN")
                .font(.bzrMono(size: 10))
                .foregroundStyle(Color.txtTertiary)
            }
          }

          BzrCard(eyebrow: "AGE · SECRETS ENCRYPTION") {
            VStack(alignment: .leading, spacing: 10) {
              Text("CHEZMOI AGE-KEYGEN · MIT · BUNDLED")
                .font(.bzrMono(size: 10))
                .foregroundStyle(Color.txtTertiary)
              BzrCodeBlock(text: """
                // generated locally · never committed
                ~/.config/chezmoi/key.txt

                // share this public key with the writer
                age1qzr...l7kq
                """)
              Button {} label: {
                HStack(spacing: 4) { Image(systemName: "doc.on.doc").font(.system(size: 11)); Text("Copy recipient") }
              }
              .buttonStyle(GlassCapsuleButtonStyle())
              Text("WRITER WILL RE-ENCRYPT TO BOTH ON NEXT PUSH")
                .font(.bzrMono(size: 9))
                .foregroundStyle(Color.txtTertiary)
            }
          }
          .frame(width: 340)
        }

        Text("Steps")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 6)

        VStack(spacing: 0) {
          ForEach(Array(steps.enumerated()), id: \.element.id) { idx, step in
            stepRow(step)
            if idx < steps.count - 1 {
              Rectangle().fill(Color.hairlineInner).frame(height: 0.5)
            }
          }
        }
        .background(Color.glassCard)
        .clipShape(RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )

        BzrCallout(
          title: "COOPERATIVE WRITER LOCK · NOT ENFORCED",
          kind: .warn,
          bodyText: ".sojourn/active.toml is a hint, not a fence. Git has no locking. We catch the 95% case of a forgotten pull. v2 adds three-way merge for text and per-file timestamps for last-writer-wins."
        )
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.onboard")
  }

  @ViewBuilder
  private func stepRow(_ s: Step) -> some View {
    HStack(spacing: 12) {
      Text(s.state == .done ? "✓" : s.id)
        .font(.bzrMono(size: 11, weight: .bold))
        .foregroundStyle(stepGlyphFg(s.state))
        .frame(width: 22, height: 22)
        .background(
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(stepGlyphBg(s.state))
        )

      Text(s.label)
        .font(.bzrStencil(size: 13, weight: .bold))
        .tracking(0.65)
        .foregroundStyle(Color.txtPrimary)
        .frame(width: 130, alignment: .leading)

      Text(s.detail)
        .font(.bzrBody(size: 12))
        .foregroundStyle(s.state == .pending ? Color.txtTertiary : Color.txtPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)

      if s.state == .active {
        StatusDot(kind: .lime)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }

  private func stepGlyphFg(_ s: Step.State) -> Color {
    switch s {
    case .done:    return .bzrVoid
    case .active:  return .bzrLime
    case .pending: return .txtTertiary
    }
  }

  private func stepGlyphBg(_ s: Step.State) -> Color {
    switch s {
    case .done:    return .bzrLime
    case .active:  return Color.bzrLime.opacity(0.20)
    case .pending: return Color.white.opacity(0.04)
    }
  }
}

// MARK: - Hygiene · Secrets (matches screens.jsx SecretsScreen)

struct SecretsPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "BUNDLED · MIT · re-signed with --options=runtime")
          .padding(.top, 8)
        Text("NO LIVE FINDINGS.")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Last scan ran on push a3f9c2e. Two false positives suppressed via repo allowlist. High-confidence provider keys (AWS, GitHub PAT, OpenAI, Stripe) cannot be bypassed for 5s — you read the warning.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        StatStrip(stats: [
          Stat(label: "Last scan",   value: "2",   unit: "hours",    kind: .neutral, meta: "a3f9c2e · pre-commit"),
          Stat(label: "Findings",    value: "0",   unit: nil,        kind: .lime,    meta: "since last push"),
          Stat(label: "Allowlisted", value: "2",   unit: nil,        kind: .neutral, meta: "test fixtures · repo-scoped"),
          Stat(label: "Rules",       value: "142", unit: nil,        kind: .neutral, meta: ".gitleaks.toml · bundled")
        ])

        Text("Last scan output")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 6)

        VStack(alignment: .leading, spacing: 0) {
          scanLogLine("14:21:58", "$",  "gitleaks dir --staged --no-git --report-format json", .secondary)
          scanLogLine("14:21:58", "→",  "scanning 47 staged files (4.2 MB)", .lime)
          scanLogLine("14:21:59", "✓",  "rule set: 142 patterns loaded from .gitleaks.toml", .ok)
          scanLogLine("14:22:00", "✓",  "dotfiles/dot_zshrc.tmpl    clean", .ok)
          scanLogLine("14:22:00", "✓",  "dotfiles/dot_gitconfig.tmpl clean", .ok)
          scanLogLine("14:22:01", "⚠",  "packages.toml:42  generic-api-key  → ALLOWLISTED (repo)", .warn)
          scanLogLine("14:22:01", "✓",  "47 files scanned, 0 findings, 2 allowlisted", .ok)
          scanLogLine("14:22:01", "━",  "commit allowed. proceeding to push.", .lime)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
            .stroke(Color.hairline, lineWidth: 0.5)
        )

        BzrCallout(
          title: "5-second lockout",
          kind: .warn,
          bodyText: "When a high-confidence provider key (aws-access-token, github-pat, openai-api-key, stripe-access-token, anthropic-api-key, slack-token) appears, the bypass button is disabled for 5 seconds. Forces the user to read."
        )

        BzrCard(title: "Bundled binary", eyebrow: "BACKEND") {
          VStack(alignment: .leading, spacing: 8) {
            Text("Sojourn ships gitleaks under Contents/Resources/bin, re-signed with the hardened runtime at build time.")
              .font(.bzrBody(size: 12))
              .foregroundStyle(Color.txtSecondary)
            BzrCodeBlock(text: "gitleaks dir --staged --report-format json --config=.gitleaks.toml")
          }
        }
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.secrets")
  }

  private enum LogTone { case secondary, ok, warn, lime }

  @ViewBuilder
  private func scanLogLine(_ ts: String, _ glyph: String, _ msg: String, _ tone: LogTone) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(ts)
        .font(.bzrMono(size: 11))
        .foregroundStyle(Color.txtTertiary)
      Text(glyph)
        .font(.bzrMono(size: 11, weight: .bold))
        .foregroundStyle(toneColor(tone))
      Text(msg)
        .font(.bzrMono(size: 11))
        .foregroundStyle(Color(red: 220/255, green: 225/255, blue: 210/255).opacity(0.85))
      Spacer(minLength: 0)
    }
    .padding(.vertical, 2)
  }

  private func toneColor(_ t: LogTone) -> Color {
    switch t {
    case .secondary: return .txtSecondary
    case .ok:        return .bzrSuccess
    case .warn:      return .bzrWarn
    case .lime:      return .bzrLime
    }
  }
}

// MARK: - App · Diagnostics (matches extras.jsx DiagnosticsScreen + ToolMatrix)

struct DiagnosticsPane: View {
  @Environment(AppStore.self) private var store
  @State private var redactionEnabled: Bool = true

  private struct Category: Identifiable {
    let id: String
    let count: String
    let meta: String
  }

  private var categories: [Category] {
    [
      .init(id: "sync",       count: "142",   meta: "last 24h"),
      .init(id: "subprocess", count: "3,481", meta: "line-buffered"),
      .init(id: "bootstrap",  count: "12",    meta: "probe + install"),
      .init(id: "secrets",    count: "7",     meta: "gitleaks runs"),
      .init(id: "cleanup",    count: "4",     meta: "trash actions"),
      .init(id: "ui",         count: "61",    meta: "interaction")
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "OSLOG-FIRST · CRASH REPORTS STAY LOCAL · NO TELEMETRY")
          .padding(.top, 8)
        Text("OBSERVABILITY.")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Six categories. .fault triggers a user-visible alert. Diagnostics bundle is the last 24h of OSLog plus AppStore.history, redacted via gitleaks-like patterns before write.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        Text("Categories")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 6)

        let cols = [
          GridItem(.flexible(), spacing: 8),
          GridItem(.flexible(), spacing: 8),
          GridItem(.flexible(), spacing: 8)
        ]
        LazyVGrid(columns: cols, spacing: 8) {
          ForEach(categories) { cat in
            categoryCard(cat)
          }
        }

        Text("Live tail · subprocess")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 6)

        VStack(alignment: .leading, spacing: 0) {
          osLogLine("14:30:01", "[sync.info]",        "SyncCoordinator.push begin · 3 candidates",                                  .secondary)
          osLogLine("14:30:01", "[subprocess.debug]", "/usr/bin/git status --porcelain=v2 --branch -z",                              .secondary)
          osLogLine("14:30:02", "[secrets.info]",     "gitleaks dir --staged --no-git --report-format json",                        .secondary)
          osLogLine("14:30:03", "[secrets.info]",     "0 findings · 2 allowlisted · 47 files",                                       .ok)
          osLogLine("14:30:03", "[subprocess.debug]", "/usr/bin/tar -czf backups/2026-04-28T14-30-pre-push.tgz dotfiles preferences", .secondary)
          osLogLine("14:30:05", "[subprocess.debug]", "/usr/bin/git commit -s -m \"install ripgrep, fd, eza · iterm2 prefs\"",       .secondary)
          osLogLine("14:30:05", "[subprocess.debug]", "/usr/bin/git push origin main",                                               .secondary)
          osLogLine("14:30:07", "[sync.info]",        "push ok · a3f9c2e → origin/main",                                             .ok)
          osLogLine("14:30:07", "[ui.error]",         "AppleScript quit timed out for com.googlecode.iterm2 (5s)",                   .warn)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
            .stroke(Color.hairline, lineWidth: 0.5)
        )

        HStack(alignment: .top, spacing: 12) {
          BzrCard(eyebrow: "REDACTION · pre-export") {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("Strip user paths and secrets from logs before export")
                  .font(.bzrBody(size: 12))
                  .foregroundStyle(Color.txtPrimary)
                Spacer()
                BzrToggle(isOn: $redactionEnabled)
              }
              Text("Same gitleaks rules as commit-time. Provider keys (AWS / GitHub PAT / OpenAI / Stripe / Anthropic / Slack) blanked to *** before bundle write.")
                .font(.bzrMono(size: 11))
                .foregroundStyle(Color.txtSecondary)
            }
          }
          BzrCard(eyebrow: "CRASH REPORTS") {
            Text("macOS submits to Apple. Sojourn never collects them. No server exists.")
              .font(.bzrMono(size: 11))
              .foregroundStyle(Color.txtSecondary)
          }
          .frame(width: 280)
        }

        Text("Tool inventory")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 6)

        toolMatrix
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.diagnostics")
  }

  @ViewBuilder
  private func categoryCard(_ cat: Category) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(cat.id)
        .font(.bzrTinyEyebrow)
        .tracking(1.6)
        .textCase(.uppercase)
        .foregroundStyle(Color.txtTertiary)
      HStack(alignment: .firstTextBaseline) {
        Text(cat.count)
          .font(.bzrMono(size: 18, weight: .bold))
          .foregroundStyle(Color.bzrLime)
        Spacer()
        Text(cat.meta)
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )
    )
  }

  private enum LogTone { case secondary, ok, warn }

  @ViewBuilder
  private func osLogLine(_ ts: String, _ tag: String, _ msg: String, _ tone: LogTone) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(ts)
        .font(.bzrMono(size: 11))
        .foregroundStyle(Color.txtTertiary)
      Text(tag)
        .font(.bzrMono(size: 11))
        .foregroundStyle(toneColor(tone))
      Text(msg)
        .font(.bzrMono(size: 11))
        .foregroundStyle(Color(red: 220/255, green: 225/255, blue: 210/255).opacity(0.85))
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 0)
    }
    .padding(.vertical, 2)
  }

  private func toneColor(_ t: LogTone) -> Color {
    switch t {
    case .secondary: return .txtTertiary
    case .ok:        return .bzrSuccess
    case .warn:      return .bzrWarn
    }
  }

  private var toolMatrix: some View {
    VStack(alignment: .leading, spacing: 0) {
      toolRowExt("xcode-select", "/usr/bin/xcode-select",                "CLT 16.2",                              .ok)
      toolRowExt("git",          "/usr/bin/git",                         "2.42.1 · system",                       .ok)
      toolRowExt("brew",         "/opt/homebrew/bin/brew",               "4.4.7 · Apple-Silicon",                 .ok)
      toolRowExt("mpm",          "/opt/homebrew/bin/mpm",                "6.3.0 · brew install",                  .ok)
      toolRowExt("chezmoi",      "/opt/homebrew/bin/chezmoi",            "2.70.2 · brew",                         .ok)
      toolRowExt("gitleaks",     "…/Resources/bin/gitleaks",             "8.30.1 · bundled · MIT",                .lime)
      toolRowExt("age",          "…/Resources/bin/age",                  "1.2.0 · bundled · MIT",                 .lime)
      toolRowExt("npm",          "~/.npm-global/bin/npm",                "— · on-demand · brew install node",     .secondary)
      toolRowExt("pnpm",         "—",                                    "— · v2 deferred · not via mpm",         .secondary)
      Text("HARDCODED CANDIDATES · NO `which` · APP-CONTEXT $PATH IS LAUNCHSERVICES-MINIMAL")
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color.txtTertiary)
        .padding(.top, 8)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )
    )
  }

  private enum ToolTone { case ok, lime, secondary }

  @ViewBuilder
  private func toolRowExt(_ name: String, _ path: String, _ note: String, _ tone: ToolTone) -> some View {
    HStack {
      Text(name)
        .font(.bzrMono(size: 11, weight: .semibold))
        .foregroundStyle(Color.txtPrimary)
        .frame(width: 110, alignment: .leading)
      Text(path)
        .font(.bzrMono(size: 11))
        .foregroundStyle(toolToneColor(tone))
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer()
      Text(note)
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color.txtTertiary)
        .frame(width: 230, alignment: .trailing)
    }
    .padding(.vertical, 5)
    .overlay(
      Rectangle().fill(Color.hairline).frame(height: 0.5).opacity(0.5),
      alignment: .bottom
    )
  }

  private func toolToneColor(_ t: ToolTone) -> Color {
    switch t {
    case .ok:        return .txtPrimary
    case .lime:      return .bzrLime
    case .secondary: return .txtTertiary
    }
  }
}

// MARK: - App · Settings (in-window embed; Settings scene still ships at ⌘,)

struct SettingsPaneEmbedded: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        EyebrowLabel(text: "APP / SETTINGS")
          .padding(.top, 8)
        Text("Settings.")
          .font(.bzrDetailH1)
          .foregroundStyle(Color.txtPrimary)
        Text("Cooldown, tier overrides, remote URL, advisory feed. Use ⌘, for the standalone macOS Settings scene.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 560, alignment: .leading)
        SettingsRoot()
          .frame(maxWidth: 600, alignment: .leading)
          .padding(.top, 12)
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.settings")
  }
}

// MARK: - Hero header helper

private struct PaneHero: View {
  let eyebrow: String
  let title: String
  let subtitle: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      EyebrowLabel(text: eyebrow)
      Text(title)
        .font(.bzrDetailH1)
        .foregroundStyle(Color.txtPrimary)
        .lineLimit(1)
      if let subtitle {
        Text(subtitle)
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 8, alignment: .leading)
      }
    }
  }
}

private struct PaneScaffold<Content: View>: View {
  let hero: PaneHero
  let content: Content

  init(hero: PaneHero, @ViewBuilder content: () -> Content) {
    self.hero = hero
    self.content = content()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        hero
        content
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Carry · Packages (matches screens.jsx PackagesScreen)

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
      .init(id: "brew",     glyph: "BR", name: "Homebrew",      pkgs: 87, outdated: 12, tier: "B", tierKind: .tierB, sub: "formulae"),
      .init(id: "cask",     glyph: "CA", name: "Cask",          pkgs: 31, outdated: 4,  tier: "C", tierKind: .tierC, sub: "gui apps"),
      .init(id: "mas",      glyph: "MA", name: "Mac App Store", pkgs: 14, outdated: 1,  tier: "A", tierKind: .tierA, sub: "mas-cli"),
      .init(id: "cargo",    glyph: "CA", name: "Cargo",         pkgs: 22, outdated: 0,  tier: "B", tierKind: .tierB, sub: "rust"),
      .init(id: "pipx",     glyph: "PI", name: "pipx",          pkgs: 11, outdated: 0,  tier: "D", tierKind: .tierD, sub: "python tools"),
      .init(id: "npm",      glyph: "NP", name: "npm (global)",  pkgs: 9,  outdated: 0,  tier: "E", tierKind: .tierE, sub: "pnpm n/a"),
      .init(id: "gem",      glyph: "GE", name: "gem",           pkgs: 6,  outdated: 0,  tier: "D", tierKind: .tierD, sub: "ruby"),
      .init(id: "composer", glyph: "CO", name: "composer",      pkgs: 4,  outdated: 0,  tier: "D", tierKind: .tierD, sub: "php")
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
              logLine("14:22:05", "$", "mpm --table-format json outdated", .secondary)
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
      .init(pkg: "ripgrep",     from: "14.1.1",  to: "14.1.4", mgr: "brew",  tier: "B", tierKind: .tierB, cooldown: "7d ✓",          state: .eligible),
      .init(pkg: "fd",          from: "10.2.1",  to: "10.3.0", mgr: "brew",  tier: "B", tierKind: .tierB, cooldown: "8d ✓",          state: .eligible),
      .init(pkg: "eza",         from: "0.18.24", to: "0.19.1", mgr: "brew",  tier: "B", tierKind: .tierB, cooldown: "12d ✓",         state: .eligible),
      .init(pkg: "zoxide",      from: "0.9.6",   to: "0.9.8",  mgr: "brew",  tier: "B", tierKind: .tierB, cooldown: "3d / 7d",       state: .cooldown),
      .init(pkg: "ghostty",     from: "1.0.4",   to: "1.1.2",  mgr: "cask",  tier: "C", tierKind: .tierC, cooldown: "9d · runs script", state: .prompt),
      .init(pkg: "Raycast",     from: "1.84.5",  to: "1.85.1", mgr: "cask",  tier: "C", tierKind: .tierC, cooldown: "5d / 7d",       state: .prompt),
      .init(pkg: "1Password 7", from: "7.9.11",  to: "7.10.0", mgr: "mas",   tier: "A", tierKind: .tierA, cooldown: "0d · ready",    state: .auto),
      .init(pkg: "typescript",  from: "5.4.2",   to: "5.6.3",  mgr: "npm",   tier: "E", tierKind: .tierE, cooldown: "21d ✓ · advisory", state: .prompt),
      .init(pkg: "mypy",        from: "1.8.0",   to: "1.11.2", mgr: "pipx",  tier: "D", tierKind: .tierD, cooldown: "14d ✓",         state: .prompt),
      .init(pkg: "cargo-watch", from: "8.4.1",   to: "8.5.3",  mgr: "cargo", tier: "B", tierKind: .tierB, cooldown: "11d ✓",         state: .eligible)
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
    case .eligible: BzrBadge(text: "READY",  kind: .success)
    case .cooldown: BzrBadge(text: "AGING",  kind: .mute)
    case .prompt:   BzrBadge(text: "PROMPT", kind: .tierC)
    case .auto:     BzrBadge(text: "AUTO",   kind: .lime)
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
        .foregroundStyle(Color(red: 220/255, green: 225/255, blue: 210/255).opacity(0.85))
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

// MARK: - Carry · Dotfiles (matches screens.jsx DotfilesScreen)

struct DotfilesPane: View {
  @State private var selectedFile: String = ".zshrc"

  var body: some View {
    HStack(spacing: 0) {
      dotfilesMidlist
      Rectangle().fill(Color.hairline).frame(width: 0.5)
      dotfileDetail
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("pane.dotfiles")
  }

  // MARK: Midlist

  private struct DotfileRow: Identifiable {
    let id: String
    let mark: String  // M / A / clean
    let path: String
    let kind: String  // modified / added / clean / encrypted / template
    let meta: String?
  }

  private var dotfileRows: [DotfileRow] {
    [
      .init(id: ".zshrc",                       mark: "M", path: ".zshrc",                       kind: "modified",  meta: "4 lines"),
      .init(id: ".gitconfig",                   mark: "M", path: ".gitconfig",                   kind: "modified",  meta: "1 line"),
      .init(id: ".config/nvim/init.lua",        mark: "A", path: ".config/nvim/init.lua",        kind: "added",     meta: "+47 −0"),
      .init(id: ".tmux.conf",                   mark: "M", path: ".tmux.conf",                   kind: "modified",  meta: "2 lines"),
      .init(id: ".config/starship.toml",        mark: " ", path: ".config/starship.toml",        kind: "clean",     meta: nil),
      .init(id: ".config/wezterm/wezterm.lua",  mark: " ", path: ".config/wezterm/wezterm.lua",  kind: "clean",     meta: nil),
      .init(id: ".aws/config",                  mark: " ", path: ".aws/config",                  kind: "encrypted", meta: "age"),
      .init(id: ".config/git/ignore",           mark: " ", path: ".config/git/ignore",           kind: "clean",     meta: nil),
      .init(id: ".npmrc",                       mark: " ", path: ".npmrc",                       kind: "template",  meta: "{{.host}}"),
      .init(id: ".config/karabiner/",           mark: " ", path: ".config/karabiner/",           kind: "clean",     meta: "12 files")
    ]
  }

  private var dotfilesMidlist: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("MANAGED · 32")
          .font(.bzrEyebrow)
          .tracking(1.6)
          .textCase(.uppercase)
          .foregroundStyle(Color.txtTertiary)
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(dotfileRows) { row in
            dotfileMidlistRow(row)
          }
        }
      }
    }
    .frame(width: 280)
    .background(Color.black.opacity(0.18))
  }

  @ViewBuilder
  private func dotfileMidlistRow(_ row: DotfileRow) -> some View {
    let selected = selectedFile == row.id
    Button { selectedFile = row.id } label: {
      HStack(spacing: 10) {
        Text(row.mark.trimmingCharacters(in: .whitespaces).isEmpty ? "·" : row.mark)
          .font(.bzrStencil(size: 12, weight: .bold))
          .foregroundStyle(markColor(row.mark))
          .frame(width: 28, height: 28)
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(markBg(row.mark))
          )

        VStack(alignment: .leading, spacing: 2) {
          Text(row.path)
            .font(.bzrBody(size: 13, weight: .semibold))
            .foregroundStyle(Color.txtPrimary)
            .lineLimit(1)
            .truncationMode(.middle)
          HStack(spacing: 4) {
            Text(row.kind)
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtTertiary)
            if let meta = row.meta {
              Text("·")
                .font(.bzrMono(size: 10))
                .foregroundStyle(Color.txtQuaternary)
              Text(meta)
                .font(.bzrMono(size: 10))
                .foregroundStyle(Color.txtTertiary)
            }
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

  private func markColor(_ m: String) -> Color {
    switch m.trimmingCharacters(in: .whitespaces) {
    case "M": return Color(red: 255/255, green: 184/255, blue: 74/255)
    case "A": return Color(red: 108/255, green: 230/255, blue: 124/255)
    default:  return Color.txtSecondary
    }
  }

  private func markBg(_ m: String) -> Color {
    switch m.trimmingCharacters(in: .whitespaces) {
    case "M": return Color.bzrWarn.opacity(0.20)
    case "A": return Color.bzrSuccess.opacity(0.20)
    default:  return Color.white.opacity(0.06)
    }
  }

  // MARK: Detail

  private var dotfileDetail: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        EyebrowLabel(text: "~/.ZSHRC · MODIFIED · OWNER ZSH (BREW)")
        Text(".ZSHRC")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)

        HStack(spacing: 8) {
          BzrBadge(text: "MODIFIED",            kind: .tierC)
          BzrBadge(text: "SOURCE · dot_zshrc.tmpl", kind: .mute)
          BzrBadge(text: "+4 −1",               kind: .mute)
          Spacer()
          Button { } label: {
            HStack(spacing: 4) { Image(systemName: "xmark").font(.system(size: 10)); Text("Discard") }
          }
          .buttonStyle(GlassGhostButtonStyle())
          Button { } label: {
            HStack(spacing: 4) { Image(systemName: "terminal").font(.system(size: 10)); Text("Open editor") }
          }
          .buttonStyle(GlassCapsuleButtonStyle())
        }

        Text("Diff · working tree → source")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 6)

        diffBlock

        HStack(alignment: .top, spacing: 12) {
          BzrCard(eyebrow: "PER-MACHINE OVERRIDE") {
            VStack(alignment: .leading, spacing: 8) {
              Text("Apply this block on:")
                .font(.bzrBody(size: 12))
                .foregroundStyle(Color.txtPrimary)
              HStack(spacing: 8) {
                BzrBadge(text: "WORK-MBP", kind: .lime)
                BzrBadge(text: "+ PERSONAL-MINI", kind: .mute)
                BzrBadge(text: "+ CI-RUNNER", kind: .mute)
              }
              Text("EXPANDS TO: {{ if eq .chezmoi.hostname \"work-mbp\" }}…{{ end }}")
                .font(.bzrMono(size: 10))
                .foregroundStyle(Color.bzrLime)
                .padding(.top, 4)
            }
          }
          BzrCard(eyebrow: "OWNERSHIP REGISTRY") {
            VStack(alignment: .leading, spacing: 6) {
              HStack(spacing: 8) { StatusDot(kind: .ok); Text("tool · zsh").font(.bzrBody(size: 12)).foregroundStyle(Color.txtPrimary) }
              HStack(spacing: 8) { StatusDot(kind: .ok); Text("source · brew").font(.bzrBody(size: 12)).foregroundStyle(Color.txtPrimary) }
              HStack(spacing: 8) { StatusDot(kind: .ok); Text("installed").font(.bzrBody(size: 12)).foregroundStyle(Color.txtPrimary) }
              Text("FROM data/dotfile_owners.toml")
                .font(.bzrMono(size: 10))
                .foregroundStyle(Color.txtTertiary)
                .padding(.top, 4)
            }
          }
          .frame(width: 240)
        }

        BzrCard(eyebrow: "BACKEND · chezmoi commands") {
          BzrCodeBlock(text: """
            chezmoi managed --format=json
            chezmoi status
            chezmoi diff --no-pager --color=false
            chezmoi merge <path>      # text dotfiles, three-way
            chezmoi apply --force     # binaries / plists only
            chezmoi update            # refresh externals
            """)
        }
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: Diff renderer

  private struct DiffLine {
    enum Kind { case ctx, add, rem, hunk }
    let kind: Kind
    let lineNum: String
    let text: String
  }

  private var diffLines: [DiffLine] {
    [
      .init(kind: .hunk, lineNum: "",   text: "@@ -42,7 +42,10 @@ # path additions"),
      .init(kind: .ctx, lineNum: "42", text: "export PATH=\"$HOME/.local/bin:$PATH\""),
      .init(kind: .ctx, lineNum: "43", text: "export PATH=\"$HOME/.cargo/bin:$PATH\""),
      .init(kind: .rem, lineNum: "44", text: "export EDITOR=vim"),
      .init(kind: .add, lineNum: "44", text: "export EDITOR=nvim"),
      .init(kind: .add, lineNum: "45", text: "export VISUAL=nvim"),
      .init(kind: .add, lineNum: "46", text: "{{- if eq .chezmoi.hostname \"work-mbp\" }}"),
      .init(kind: .add, lineNum: "47", text: "export AWS_PROFILE=acme-prod"),
      .init(kind: .add, lineNum: "48", text: "{{- end }}"),
      .init(kind: .ctx, lineNum: "49", text: ""),
      .init(kind: .ctx, lineNum: "50", text: "# aliases")
    ]
  }

  private var diffBlock: some View {
    VStack(spacing: 0) {
      ForEach(Array(diffLines.enumerated()), id: \.offset) { _, line in
        diffLineView(line)
      }
    }
    .padding(.vertical, 10)
    .background(Color.black.opacity(0.40))
    .clipShape(RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
        .stroke(Color.hairline, lineWidth: 0.5)
    )
  }

  @ViewBuilder
  private func diffLineView(_ line: DiffLine) -> some View {
    switch line.kind {
    case .hunk:
      Text(line.text)
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color(red: 155/255, green: 196/255, blue: 255/255))
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bzrInfo.opacity(0.10))
    case .add, .rem, .ctx:
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        Text(line.lineNum)
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtQuaternary)
          .frame(width: 24, alignment: .trailing)
          .padding(.trailing, 6)
        Text(diffMarker(line.kind))
          .font(.bzrMono(size: 11, weight: .bold))
          .foregroundStyle(diffColor(line.kind))
          .frame(width: 12)
        Text(line.text)
          .font(.bzrMono(size: 11))
          .foregroundStyle(diffTextColor(line.kind))
          .lineLimit(1)
          .truncationMode(.tail)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 2)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(diffBg(line.kind))
    }
  }

  private func diffMarker(_ k: DiffLine.Kind) -> String {
    switch k {
    case .add: return "+"
    case .rem: return "−"
    default:   return " "
    }
  }

  private func diffColor(_ k: DiffLine.Kind) -> Color {
    switch k {
    case .add: return .bzrSuccess
    case .rem: return .bzrDanger
    default:   return .txtTertiary
    }
  }

  private func diffTextColor(_ k: DiffLine.Kind) -> Color {
    switch k {
    case .add: return Color(red: 184/255, green: 240/255, blue: 192/255)
    case .rem: return Color(red: 255/255, green: 184/255, blue: 188/255)
    default:   return Color.txtTertiary
    }
  }

  private func diffBg(_ k: DiffLine.Kind) -> Color {
    switch k {
    case .add: return Color.bzrSuccess.opacity(0.10)
    case .rem: return Color.bzrDanger.opacity(0.10)
    default:   return Color.clear
    }
  }
}

// MARK: - Carry · Preferences (matches screens.jsx PreferencesScreen)

struct PreferencesPane: View {
  @State private var selectedDomain: String = "com.googlecode.iterm2"

  var body: some View {
    HStack(spacing: 0) {
      domainsMidlist
      Rectangle().fill(Color.hairline).frame(width: 0.5)
      domainDetail
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("pane.preferences")
  }

  private struct PrefDomain: Identifiable {
    let id: String   // bundle id
    let name: String
    let scope: String  // unsandboxed / app-supp / sandboxed
    let mark: String   // M / clean
    let format: String // XML / JSON / FDA
  }

  private var prefDomains: [PrefDomain] {
    [
      .init(id: "com.googlecode.iterm2",       name: "iTerm2",      scope: "unsandboxed", mark: "M", format: "XML"),
      .init(id: "com.apple.dock",              name: "Dock",        scope: "unsandboxed", mark: "M", format: "XML"),
      .init(id: "com.apple.finder",            name: "Finder",      scope: "unsandboxed", mark: " ", format: "XML"),
      .init(id: "com.raycast.macos",           name: "Raycast",     scope: "unsandboxed", mark: " ", format: "XML"),
      .init(id: "com.knollsoft.Rectangle",     name: "Rectangle",   scope: "unsandboxed", mark: " ", format: "XML"),
      .init(id: "org.pqrs.Karabiner-Elements", name: "Karabiner",   scope: "app-supp",    mark: "M", format: "JSON"),
      .init(id: "com.agilebits.onepassword4",  name: "1Password 7", scope: "sandboxed",   mark: " ", format: "FDA"),
      .init(id: "com.apple.Safari",            name: "Safari",      scope: "sandboxed",   mark: " ", format: "FDA"),
      .init(id: "com.apple.TextEdit",          name: "TextEdit",    scope: "unsandboxed", mark: " ", format: "XML"),
      .init(id: "com.apple.Terminal",          name: "Terminal",    scope: "unsandboxed", mark: " ", format: "XML")
    ]
  }

  private var domainsMidlist: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("DOMAINS · 18")
          .font(.bzrEyebrow)
          .tracking(1.6)
          .textCase(.uppercase)
          .foregroundStyle(Color.txtTertiary)
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(prefDomains) { d in
            domainMidlistRow(d)
          }
        }
      }
    }
    .frame(width: 280)
    .background(Color.black.opacity(0.18))
  }

  @ViewBuilder
  private func domainMidlistRow(_ d: PrefDomain) -> some View {
    let selected = selectedDomain == d.id
    Button { selectedDomain = d.id } label: {
      HStack(spacing: 10) {
        Text(String(d.name.prefix(2)))
          .font(.bzrStencil(size: 12, weight: .bold))
          .foregroundStyle(d.mark == "M" ? Color(red: 255/255, green: 184/255, blue: 74/255) : Color.txtSecondary)
          .frame(width: 28, height: 28)
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(d.mark == "M" ? Color.bzrWarn.opacity(0.20) : Color.white.opacity(0.06))
          )

        VStack(alignment: .leading, spacing: 2) {
          Text(d.name)
            .font(.bzrBody(size: 13, weight: .semibold))
            .foregroundStyle(Color.txtPrimary)
          Text(d.id)
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        Spacer()
        if d.scope == "sandboxed" {
          Image(systemName: "lock.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.bzrWarn)
        }
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

  private var domainDetail: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        EyebrowLabel(text: "com.googlecode.iterm2 · UNSANDBOXED · LAYER 1")
        Text("iTerm2")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        HStack(spacing: 8) {
          BzrBadge(text: "UNSANDBOXED · NO FDA", kind: .success)
          BzrBadge(text: "MODIFIED",            kind: .tierC)
          BzrBadge(text: "XML · 47KB",          kind: .mute)
          BzrBadge(text: "214 KEYS",            kind: .mute)
          Spacer()
        }
        Text("Round-tripped through cfprefsd via defaults export + defaults import. Stored as XML so git diffs are legible. iTerm2 will be quit-and-relaunched on import.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        Text("Plist diff (since last export)")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 6)

        BzrCodeBlock(text: """
          // 7 keys changed since 2026-04-26 14:22

          PrefsCustomFolder            = "~/.config/iterm2"
          + NewBookmarks[0].Working Directory = "~/code/sojourn"
          + NewBookmarks[0].Custom Window Title = "sojourn ✦"
          ~ Normal Font                = "JetBrainsMono-Regular 13"
          ~ Cursor Type                = 2  (was 1)
          ~ Use Bold Font              = 1  (was 0)
          + Window Style               = 2  (no titlebar)
          − Theme Path                 = "~/Downloads/old-theme.json"
          """)

        BzrCallout(
          title: "QUIT-AND-RELAUNCH ON IMPORT",
          kind: .warn,
          bodyText: "cfprefsd rewrites plists via atomic rename. If iTerm2 is running when Sojourn calls defaults import, your in-flight changes win. Sojourn will AppleScript-quit it on apply, write the plist, then relaunch."
        )

        BzrCard(title: "Plist layers", eyebrow: "DEFAULTS · FOUR LAYER MODEL") {
          VStack(alignment: .leading, spacing: 10) {
            layerRow("user",           "~/Library/Preferences/com.<app>.plist",                       .lime,   "default", .lime)
            layerRow("system",         "/Library/Preferences/com.<app>.plist",                        .ok,     "root",    .mute)
            layerRow("sandboxed",      "~/Library/Containers/<bundle>/Data/Library/Preferences/",     .warn,   "FDA",     .warn)
            layerRow("apple-internal", "non-standard, undocumented",                                  .danger, "skip",    .danger)
          }
        }

        BzrCallout(
          title: "FDA canary",
          kind: .warn,
          bodyText: "Sojourn probes /Library/Preferences/com.apple.TimeMachine.plist on first launch to detect Full Disk Access. Without it, sandboxed plists are skipped."
        )
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private func layerRow(_ layer: String, _ path: String, _ kind: StatusDotKind, _ tag: String, _ tagKind: BzrBadgeKind) -> some View {
    HStack(spacing: 10) {
      StatusDot(kind: kind)
      VStack(alignment: .leading, spacing: 2) {
        Text(layer.uppercased())
          .font(.bzrTinyEyebrow)
          .tracking(1.6)
          .foregroundStyle(Color.txtSecondary)
        Text(path)
          .font(.bzrCode)
          .foregroundStyle(Color.txtPrimary)
      }
      Spacer()
      BzrBadge(text: tag, kind: tagKind)
    }
  }
}

// MARK: - Sync · History (matches screens.jsx HistoryScreen)

struct HistoryPane: View {
  @Environment(AppStore.self) private var store

  private struct TimelineEntry: Identifiable {
    let id = UUID()
    let sha: String
    let when: String
    let kind: String
    let kindBadge: BzrBadgeKind
    let message: String
    let machine: String
    let stats: String?
    let snapshot: String?
    let nodeColor: NodeColor

    enum NodeColor { case lime, warn, mute }
  }

  // Demo data; replaced by store.history projection in Phase B.
  private var demoEntries: [TimelineEntry] {
    [
      .init(sha: "a3f9c2e", when: "2h ago",  kind: "PUSH",     kindBadge: .lime,  message: "mpm install ripgrep, fd, eza",          machine: "work-mbp",       stats: "+24 −2",   snapshot: nil,                              nodeColor: .lime),
      .init(sha: "7b1de44", when: "1d ago",  kind: "PULL",     kindBadge: .mute,  message: "sync from personal-mini · 6 changes",   machine: "work-mbp",       stats: "+183 −47", snapshot: "snap_2026-04-27T08-12.tgz",       nodeColor: .lime),
      .init(sha: "c08fa12", when: "2d ago",  kind: "PUSH",     kindBadge: .mute,  message: "iterm2 prefs · zshrc edit",             machine: "personal-mini",  stats: "+12 −4",   snapshot: nil,                              nodeColor: .mute),
      .init(sha: "ee31a09", when: "3d ago",  kind: "APPLY",    kindBadge: .mute,  message: "chezmoi apply --force after pull",      machine: "work-mbp",       stats: "4 files",  snapshot: "snap_2026-04-25T19-02.tgz",       nodeColor: .mute),
      .init(sha: "114b8f0", when: "4d ago",  kind: "CLEAN",    kindBadge: .mute,  message: "trashed 8 dotfile orphans",             machine: "work-mbp",       stats: "−2.4GB",   snapshot: "deletions.db row#341",            nodeColor: .mute),
      .init(sha: "82de019", when: "5d ago",  kind: "CONFLICT", kindBadge: .tierC, message: "resolved · keep local .zshrc",          machine: "work-mbp",       stats: nil,        snapshot: nil,                              nodeColor: .warn),
      .init(sha: "44ab821", when: "6d ago",  kind: "PUSH",     kindBadge: .mute,  message: "cargo update + Raycast prefs",          machine: "personal-mini",  stats: "+9 −9",    snapshot: nil,                              nodeColor: .mute)
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "WORK-MBP ↔ origin · git@github.com:you/my-mac.git")
          .padding(.top, 8)
        Text("47 COMMITS · 12 SNAPSHOTS")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Pre-op tarballs retained 30 days. Every push is gitleaks-scanned. Every pull writes a snapshot before touching the working tree. Roll back without leaving the app.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        timelineCard
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.history")
  }

  private var timelineCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("TIMELINE · HEAD ← origin/main")
          .font(.bzrTinyEyebrow)
          .tracking(1.6)
          .textCase(.uppercase)
          .foregroundStyle(Color.txtTertiary)
        Spacer()
        Text("RETENTION · 30D")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .overlay(
        Rectangle().fill(Color.hairline).frame(height: 0.5),
        alignment: .bottom
      )

      // Timeline rail.
      VStack(alignment: .leading, spacing: 0) {
        ForEach(demoEntries) { entry in
          timelineRow(entry)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )
    )
  }

  @ViewBuilder
  private func timelineRow(_ entry: TimelineEntry) -> some View {
    HStack(alignment: .top, spacing: 14) {
      timelineNode(entry.nodeColor)
        .padding(.top, 4)
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Text(entry.sha)
            .font(.bzrMono(size: 11, weight: .semibold))
            .foregroundStyle(Color.bzrLime)
          BzrBadge(text: entry.kind, kind: entry.kindBadge)
          Text(entry.message)
            .font(.bzrBody(size: 12, weight: .semibold))
            .foregroundStyle(Color.txtPrimary)
          Spacer()
          Text(entry.when)
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
        }
        HStack(spacing: 6) {
          Image(systemName: "laptopcomputer")
            .font(.system(size: 9))
            .foregroundStyle(Color.txtTertiary)
          Text(entry.machine)
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
          if let stats = entry.stats {
            Text("·")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtQuaternary)
            Text(stats)
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtTertiary)
          }
          if let snapshot = entry.snapshot {
            Text("·")
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtQuaternary)
            Image(systemName: "archivebox")
              .font(.system(size: 9))
              .foregroundStyle(Color.bzrLime)
            Text(snapshot)
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.bzrLime)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          Spacer()
          Button {} label: {
            Text("↶ Roll back")
              .font(.bzrMono(size: 10))
          }
          .buttonStyle(GlassGhostButtonStyle())
        }
      }
    }
    .padding(.vertical, 10)
  }

  @ViewBuilder
  private func timelineNode(_ kind: TimelineEntry.NodeColor) -> some View {
    let color: Color = {
      switch kind {
      case .lime: return .bzrLime
      case .warn: return .bzrWarn
      case .mute: return .bzrVoid3
      }
    }()
    Circle()
      .fill(color)
      .frame(width: 13, height: 13)
      .overlay(
        Circle().stroke(color, lineWidth: 1)
      )
      .shadow(color: kind == .lime ? color : Color.clear, radius: 4)
  }
}

// MARK: - Sync · Machines (matches screens.jsx MachinesScreen)

struct MachinesPane: View {
  private struct Machine: Identifiable {
    let id: String
    let host: String
    let model: String
    let os: String
    let lastSync: String
    let writer: Bool
    let pkgs: Int
    let role: String
  }

  private var fleet: [Machine] {
    [
      .init(id: "work-mbp",      host: "mbp16-acme.local", model: "MacBook Pro 16\" · M3 Max", os: "14.5 Sonoma",  lastSync: "2h ago", writer: true,  pkgs: 184, role: "PRIMARY"),
      .init(id: "personal-mini", host: "mini-home.local",  model: "Mac mini · M4",             os: "15.1 Sequoia", lastSync: "2d ago", writer: false, pkgs: 142, role: "PERSONAL"),
      .init(id: "ci-runner",     host: "gh-runner-arm-04", model: "M2 in a closet",            os: "14.2 Sonoma",  lastSync: "6h ago", writer: false, pkgs: 67,  role: "EPHEMERAL")
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "3 MACHINES · 1 ACTIVE WRITER · COOPERATIVE LOCK")
          .padding(.top, 8)
        Text("YOUR FLEET")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("One active writer at a time. Pull before push. The lock is a hint git doesn't enforce — it catches the 95% case of a forgotten pull. Per-machine overrides via {{ if eq .chezmoi.hostname \"...\" }} are generated by the form.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        let cols = [
          GridItem(.flexible(minimum: 320), spacing: 12),
          GridItem(.flexible(minimum: 320), spacing: 12),
          GridItem(.flexible(minimum: 320), spacing: 12)
        ]
        LazyVGrid(columns: cols, spacing: 12) {
          ForEach(fleet) { m in
            machineCard(m)
          }
        }

        Text("Repo · git@github.com:you/my-mac.git")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 6)

        BzrCard {
          BzrCodeBlock(text: """
            my-mac/
            ├── packages.toml                 // mpm backup output
            ├── dotfiles/                     // chezmoi source dir
            │   ├── dot_zshrc.tmpl
            │   ├── dot_gitconfig.tmpl
            │   └── private_dot_ssh/encrypted_id_ed25519.age
            ├── preferences/                  // XML plist per domain
            │   ├── com.googlecode.iterm2.plist
            │   └── com.apple.dock.plist
            └── .sojourn/
                ├── machines/work-mbp.toml
                ├── active.toml               // writer = "work-mbp"
                ├── version.toml
                └── backups/                  // pre-op snapshots, 30d
            """)
        }
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.machines")
  }

  @ViewBuilder
  private func machineCard(_ m: Machine) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          StatusDot(kind: m.writer ? .lime : .ok)
          Text(m.id.uppercased())
            .font(.bzrStencil(size: 18, weight: .heavy))
            .tracking(1.6)
            .foregroundStyle(Color.txtPrimary)
          Spacer()
          Text(m.role)
            .font(.bzrMono(size: 9, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Color.txtTertiary)
        }
        Text(m.host)
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(m.writer ? Color.bzrLime.opacity(0.10) : Color.white.opacity(0.02))
      .overlay(
        Rectangle()
          .fill(m.writer ? Color.bzrLime.opacity(0.30) : Color.hairline)
          .frame(height: 0.5),
        alignment: .bottom
      )

      VStack(alignment: .leading, spacing: 6) {
        machineRow("Model",    m.model)
        machineRow("OS",       m.os)
        machineRow("Packages", "\(m.pkgs)", lime: true)
        machineRow("Last sync", m.lastSync)
        HStack(spacing: 6) {
          Text("Writer")
            .font(.bzrBody(size: 12))
            .foregroundStyle(Color.txtTertiary)
            .frame(width: 80, alignment: .leading)
          if m.writer {
            BzrBadge(text: "ACTIVE", kind: .lime)
          } else {
            BzrBadge(text: "TAKE LOCK", kind: .mute)
          }
          Spacer()
        }
        .padding(.top, 4)

        HStack(spacing: 8) {
          Button {} label: {
            HStack(spacing: 4) { Image(systemName: "terminal").font(.system(size: 11)); Text("Open in iTerm") }
          }
          .buttonStyle(GlassCapsuleButtonStyle())
          if m.writer {
            Button {} label: { Image(systemName: "gearshape").font(.system(size: 11)) }
              .buttonStyle(GlassGhostButtonStyle())
          }
          Spacer()
        }
        .padding(.top, 8)
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
        .frame(width: 80, alignment: .leading)
      if lime {
        Text(value)
          .font(.bzrMono(size: 12, weight: .semibold))
          .foregroundStyle(Color.bzrLime)
      } else {
        Text(value)
          .font(.bzrBody(size: 12))
          .foregroundStyle(Color.txtPrimary)
      }
      Spacer()
    }
  }
}

// MARK: - Hygiene · Cleanup (matches screens.jsx CleanupScreen)

struct CleanupPane: View {
  @Environment(AppStore.self) private var store
  @State private var scanning = false

  private struct OrphanRow: Identifiable {
    let id = UUID()
    let selected: Bool
    let path: String
    let size: String
    let owner: String
    let klass: String
    let klassKind: BzrBadgeKind
    let lastTouched: String
    let action: String
  }

  // Demo rows — replaced by store.orphans projection in Phase B.
  private var demoRows: [OrphanRow] {
    [
      .init(selected: true,  path: "~/.rbenv/",                                    size: "412 MB", owner: "rbenv (brew · uninstalled 2025-12-04)",        klass: "SAFE",   klassKind: .success, lastTouched: "142 days", action: "TRASH"),
      .init(selected: true,  path: "~/.nvm/",                                      size: "1.1 GB", owner: "nvm (curl · uninstalled)",                     klass: "SAFE",   klassKind: .success, lastTouched: "98 days",  action: "TRASH"),
      .init(selected: true,  path: "~/.config/old-fish/",                          size: "8.4 MB", owner: "fish shell (not in brew · zsh active)",        klass: "REVIEW", klassKind: .tierC,   lastTouched: "211 days", action: "TRASH"),
      .init(selected: true,  path: "~/Library/Application Support/Atom/",          size: "887 MB", owner: "com.github.atom (no bundle ID found)",         klass: "REVIEW", klassKind: .tierC,   lastTouched: "3 years",  action: "TRASH"),
      .init(selected: false, path: "~/.docker/",                                   size: "3.2 MB", owner: "Docker (cask · still installed)",              klass: "KEEP",   klassKind: .mute,    lastTouched: "2 days",   action: "—"),
      .init(selected: false, path: "~/.zsh_sessions/",                             size: "21 MB",  owner: "zsh (system · active)",                        klass: "RISKY",  klassKind: .tierE,   lastTouched: "2 hours",  action: "—"),
      .init(selected: false, path: "~/Library/LaunchAgents/com.heroku.cli.plist",  size: "2 KB",   owner: "heroku (brew · uninstalled)",                  klass: "RISKY",  klassKind: .tierE,   lastTouched: "62 days",  action: "prompt")
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "HYGIENE / DOTFILE ORPHANS / RECONCILED AGAINST TOOL INVENTORY")
          .padding(.top, 8)
        Text("12 ORPHANS · 2.4GB")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Reconciled against brew list, pipx list, $PATH probes, and data/dotfile_owners.toml. Shell history grep, last-used xattrs, and parent-dir mtime gate the call. Never auto-delete. Always Trash.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        BzrCallout(
          title: "APFS atime is not trustworthy",
          kind: .danger,
          bodyText: "Default mount is non-strict atime. Quick Look ticks it. Spotlight ticks it. We use it as a tiebreaker only. Read the docs if you care."
        )

        HStack {
          Button {
            Task {
              scanning = true
              await store.rescanOrphans()
              scanning = false
            }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: scanning ? "arrow.clockwise" : "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
              Text(scanning ? "Scanning…" : "Scan ~/Library")
            }
          }
          .buttonStyle(GlassCapsuleButtonStyle())
          .disabled(scanning)
          .accessibilityIdentifier("pane.cleanup.scan")

          Spacer()

          Button {} label: {
            HStack(spacing: 6) {
              Image(systemName: "trash")
                .font(.system(size: 11, weight: .semibold))
              Text("Move 4 to Trash")
            }
          }
          .buttonStyle(GlassDangerButtonStyle())
        }

        Text("Orphan candidates")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 4)

        orphanTable

        Text("↻ DELETIONS LOGGED TO ~/Library/Application Support/Sojourn/deletions.db · 10 MOST RECENT UNDOABLE")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.cleanup")
  }

  private var orphanTable: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 0) {
        orphanHeader("",            width: 28)
        orphanHeader("Path",        width: 240)
        orphanHeader("Size",        width: 80)
        orphanHeader("Owner (missing)", width: 240)
        orphanHeader("Class",       width: 80)
        orphanHeader("Last touched", width: 100)
        orphanHeader("Action",      width: 80)
      }
      .background(Color.white.opacity(0.02))
      .overlay(
        Rectangle().fill(Color.hairline).frame(height: 0.5),
        alignment: .bottom
      )

      ForEach(demoRows) { row in
        HStack(spacing: 0) {
          // Checkbox
          HStack {
            Image(systemName: row.selected ? "checkmark.square.fill" : "square")
              .font(.system(size: 12))
              .foregroundStyle(row.selected ? Color.bzrLime : Color.txtTertiary)
            Spacer()
          }
          .frame(width: 28).padding(.horizontal, 8).padding(.vertical, 7)

          orphanCell(row.path, width: 240, color: .txtPrimary, weight: .semibold)
          orphanCell(row.size, width: 80, color: .txtTertiary)
          orphanCell(row.owner, width: 240, color: .txtTertiary)
          HStack { BzrBadge(text: row.klass, kind: row.klassKind); Spacer() }
            .frame(width: 80).padding(.horizontal, 12).padding(.vertical, 7)
          orphanCell(row.lastTouched, width: 100, color: .txtTertiary)
          HStack {
            if row.action == "—" {
              Text("—").font(.bzrMono(size: 10)).foregroundStyle(Color.txtTertiary)
            } else if row.action == "prompt" {
              Text("prompt").font(.bzrMono(size: 10)).foregroundStyle(Color.txtTertiary)
            } else {
              BzrBadge(text: row.action, kind: .mute)
            }
            Spacer()
          }
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
  private func orphanHeader(_ text: String, width: CGFloat) -> some View {
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
  private func orphanCell(_ text: String, width: CGFloat, color: Color, weight: Font.Weight = .medium) -> some View {
    Text(text)
      .font(.bzrMono(size: 11, weight: weight))
      .foregroundStyle(color)
      .frame(width: width, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .lineLimit(1)
      .truncationMode(.middle)
  }

  private func badgeKind(for c: OrphanCandidate.Category) -> BzrBadgeKind {
    switch c {
    case .safe:   return .success
    case .review: return .warn
    case .risky:  return .danger
    }
  }
}
