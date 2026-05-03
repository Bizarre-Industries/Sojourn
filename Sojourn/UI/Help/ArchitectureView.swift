// Sojourn — Architecture reference view.
//
// SwiftUI translation of `project/architecture.jsx`. Opened from the
// Help menu (`SojournApp.commands`). The view is the "how Sojourn talks
// to your Mac" diagram — UI / State / Services / Backends with the
// brew bundle / chezmoi licensing firewall called out, plus a bottom strip for
// persistence layout, scheduler config, and the user's repo shape.

import SwiftUI

struct ArchitectureView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        header
        layerGrid
        flowLane
        bottomStrip
        signature
      }
      .padding(40)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Color.bzrVoid)
    .frame(minWidth: 1024, minHeight: 720)
    .accessibilityIdentifier("help.architecture")
  }

  // MARK: Header

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 12) {
        Text("SOJOURN / ARCHITECTURE / A NATIVE MAC THAT WRAPS THE TOOLS YOU ALREADY TRUST")
          .font(.bzrEyebrow)
          .tracking(1.8)
          .textCase(.uppercase)
          .foregroundStyle(Color.bzrLimeText)

        HStack(alignment: .firstTextBaseline, spacing: 16) {
          Text("THE BENCH IS HONEST.")
            .font(.bzrStencil(size: 48, weight: .heavy))
            .foregroundStyle(Color.txtPrimary)
          Text("NO LINKING.")
            .font(.bzrStencil(size: 48, weight: .heavy))
            .foregroundStyle(Color.bzrLimeText)
        }

        Text("Sojourn is a SwiftUI app over swift-subprocess. Every backend (chezmoi, brew, git, gitleaks, age, defaults) runs as a separate process with structured I/O. This is the licensing firewall — GPL-3-or-later code lives at arms length from GPL-2 git via subprocess only. JSON in, TOML out, exit codes everywhere.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 980, alignment: .leading)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text("SWIFT 6.1+ · macOS 14+ · @Observable")
          .font(.bzrMono(size: 10))
          .tracking(1.6)
          .foregroundStyle(Color.txtTertiary)
        Text("app.bizarre.sojourn · v1.0")
          .font(.bzrMono(size: 11))
          .foregroundStyle(Color.bzrLimeText)
      }
    }
  }

  // MARK: Four layers

  private var layerGrid: some View {
    let cols = [
      GridItem(.flexible(), spacing: 12),
      GridItem(.flexible(), spacing: 12),
      GridItem(.flexible(), spacing: 12),
      GridItem(.flexible(), spacing: 12)
    ]
    return LazyVGrid(columns: cols, spacing: 12) {
      uiLayer
      stateLayer
      servicesLayer
      backendsLayer
    }
  }

  private var uiLayer: some View {
    Layer(label: "UI", sub: "SwiftUI · Liquid Glass · MenuBarExtra", tone: .lime) {
      Block(title: "MainWindow", lines: ["Sidebar (Carry / Sync / Hygiene / App / Power)", "Mid-list", "Detail + log pane"])
      Block(title: "MenuBarExtra", lines: ["LSUIElement", "MenuBarExtraAccess", "Quick Pull / Push"])
      Block(title: "Sheets", lines: ["Push", "Pull", "SecretFindings · 5s lock", "BootstrapView"])
      Text("READS APPSTORE · DISPATCHES INTENTS")
        .font(.bzrMono(size: 9, weight: .semibold))
        .tracking(1.4)
        .foregroundStyle(Color.bzrLimeText)
    }
  }

  private var stateLayer: some View {
    Layer(label: "STATE", sub: "Observation framework · no TCA", tone: .white) {
      Block(title: "AppStore", lines: ["@Observable", "managers, history, jobs", "bootstrapState, settings"])
      Block(title: "JobRunner", lines: ["Task per Job", "cancellable", "pipes → LogBuffer"])
      Block(title: "LogBuffer", lines: ["ring buffer", "AttributedString rows", "ANSI SGR parser"])
      Text("SINGLE ROOT STORE · @MainActor")
        .font(.bzrMono(size: 9, weight: .semibold))
        .tracking(1.4)
        .foregroundStyle(Color.txtTertiary)
    }
  }

  private var servicesLayer: some View {
    Layer(label: "SERVICES", sub: "actor per CLI · structured I/O", tone: .white) {
      Svc(name: "BrewBundleService", cli: "brew bundle", out: "dump install check cyclonedx", kind: .normal)
      Svc(name: "ChezmoiService", cli: "chezmoi", out: "--format=json · status · diff", kind: .normal)
      Svc(name: "GitService", cli: "/usr/bin/git", out: "--porcelain=v2 -z", kind: .normal)
      Svc(name: "PrefService", cli: "defaults", out: "export/import + plutil xml1", kind: .normal)
      Svc(name: "SecretScan", cli: "gitleaks", out: "dir --report-format json", kind: .warn)
      Svc(name: "BrewService", cli: "brew", out: ".pkg installer · Authorization", kind: .normal)
      Text("ALL VIA swift-subprocess")
        .font(.bzrMono(size: 9, weight: .semibold))
        .tracking(1.4)
        .foregroundStyle(Color.txtTertiary)
    }
  }

  private var backendsLayer: some View {
    Layer(label: "BACKENDS", sub: "user's binaries · arm's length", tone: .amber) {
      Backend(bin: "brew", path: "/opt/homebrew/bin/brew", license: "BSD-2", pinned: "5.x+")
      Backend(bin: "chezmoi", path: "/opt/homebrew/bin/chezmoi", license: "MIT", pinned: "2.70.2+")
      Backend(bin: "brew", path: "/opt/homebrew/bin/brew", license: "BSD-2", pinned: "4.4.7+")
      Backend(bin: "git", path: "/usr/bin/git", license: "GPL-2", pinned: "system")
      Backend(bin: "gitleaks", path: "…/Resources/bin/", license: "MIT", pinned: "bundled · re-signed")
      Backend(bin: "age", path: "…/Resources/bin/", license: "MIT", pinned: "bundled · re-signed")
      Text("LICENSING FIREWALL · NO LINKING")
        .font(.bzrMono(size: 9, weight: .semibold))
        .tracking(1.4)
        .foregroundStyle(Color.bzrWarn)
    }
  }

  // MARK: Flow lane

  private var flowLane: some View {
    HStack(spacing: 14) {
      Text("EVERY SUBPROCESS IS A JOB")
        .font(.bzrMono(size: 10, weight: .semibold))
        .tracking(1.8)
        .foregroundStyle(Color.bzrLimeText)
      Text("·").foregroundStyle(Color.txtTertiary)
      Text("id · start · status · line-buffered log · cancellable · 64KB pipe backpressure handled")
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color.txtSecondary)
      Text("·").foregroundStyle(Color.txtTertiary)
      Text("PTY-wrap for block-buffered tools (script -q /dev/null)")
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color.txtSecondary)
      Spacer()
      Text("FAULT → user-visible alert")
        .font(.bzrMono(size: 10, weight: .semibold))
        .foregroundStyle(Color.bzrLimeText)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .background(Color.bzrLime.opacity(0.04))
    .overlay(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .stroke(Color.bzrLime.opacity(0.20), lineWidth: 0.5)
    )
    .overlay(
      Rectangle()
        .fill(Color.bzrLime)
        .frame(width: 3),
      alignment: .leading
    )
  }

  // MARK: Bottom strip

  private var bottomStrip: some View {
    HStack(alignment: .top, spacing: 14) {
      BottomCard(title: "PERSISTENCE", sub: "~/Library/Application Support/Sojourn", rows: [
        ("settings.toml", "tool paths · cooldown overrides · machine_id"),
        ("backups/<ts>-<op>/", "tarball before push/pull/apply · 30d GC"),
        ("deletions.db", "SQLite · path · sha256 · reason · undo log"),
        ("logs/", "OSLog export bundle · gitleaks-redacted")
      ])
      BottomCard(title: "SCHEDULING", sub: "NSBackgroundActivityScheduler", rows: [
        ("activity-id", "app.bizarre.sojourn.refresh-outdated"),
        ("interval / tolerance", "1h · 15m · QoS .utility"),
        ("App Nap", "respected · battery-aware"),
        ("v1.1 opt-in", "SMAppService.agent · LaunchAgent")
      ])
      BottomCard(title: "USER REPO · YOUR REMOTE", sub: "git@github.com:you/my-mac.git", rows: [
        ("Brewfile.common", "brew bundle dump · root · DSL"),
        ("dotfiles/", "chezmoi source dir · age-encrypted secrets"),
        ("preferences/*.plist", "XML · per-domain · git-diffable"),
        (".sojourn/", "machines/ · active.toml · backups/ · version.toml")
      ])
    }
  }

  // MARK: Signature

  private var signature: some View {
    HStack(alignment: .bottom) {
      Text("UI NEVER CALLS Process — SERVICES NEVER LINK BACKENDS — BACKENDS NEVER SEE OUR PROCESS SPACE")
        .font(.bzrMono(size: 10))
        .tracking(1.6)
        .foregroundStyle(Color.txtTertiary)
      Spacer()
      HStack(spacing: 6) {
        Text("SOJOURN")
          .font(.bzrStencil(size: 18, weight: .heavy))
          .tracking(1.6)
          .foregroundStyle(Color.bzrLimeText)
        Text("×")
          .font(.bzrStencil(size: 18, weight: .heavy))
          .foregroundStyle(Color.txtTertiary)
        Text("BIZARRE")
          .font(.bzrStencil(size: 18, weight: .heavy))
          .tracking(1.6)
          .foregroundStyle(Color.bzrLimeText)
      }
    }
    .padding(.top, 12)
  }
}

// MARK: - Layer container

private enum LayerTone { case lime, white, amber }

private struct Layer<Content: View>: View {
  let label: String
  let sub: String
  let tone: LayerTone
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.bzrStencil(size: 16, weight: .heavy))
          .tracking(1.6)
          .foregroundStyle(toneColor)
        Text(sub)
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(.bottom, 4)
      content()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(toneColor.opacity(0.30), lineWidth: 0.5)
        )
    )
  }

  private var toneColor: Color {
    switch tone {
    case .lime:  return .bzrLime
    case .white: return .txtPrimary
    case .amber: return .bzrWarn
    }
  }
}

// MARK: - Block (UI / State columns)

private struct Block: View {
  let title: String
  let lines: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.bzrBody(size: 12, weight: .bold))
        .foregroundStyle(Color.txtPrimary)
      ForEach(lines, id: \.self) { line in
        Text("· \(line)")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtSecondary)
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Service row (Services column)

private struct Svc: View {
  let name: String
  let cli: String
  let out: String
  let kind: Kind

  enum Kind { case normal, warn }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(name)
          .font(.bzrBody(size: 11, weight: .semibold))
          .foregroundStyle(kind == .warn ? Color.bzrWarn : Color.txtPrimary)
        Text("→")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
        Text(cli)
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.bzrLimeText)
      }
      Text(out)
        .font(.bzrMono(size: 9))
        .foregroundStyle(Color.txtTertiary)
    }
    .padding(.vertical, 3)
  }
}

// MARK: - Backend row (Backends column)

private struct Backend: View {
  let bin: String
  let path: String
  let license: String
  let pinned: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline) {
        Text(bin)
          .font(.bzrBody(size: 11, weight: .semibold))
          .foregroundStyle(Color.txtPrimary)
        Spacer()
        Text(license)
          .font(.bzrMono(size: 9, weight: .semibold))
          .foregroundStyle(license.contains("GPL-2") ? Color.bzrWarn : Color.txtTertiary)
      }
      Text(path)
        .font(.bzrMono(size: 9))
        .foregroundStyle(Color.bzrLimeText)
      Text(pinned)
        .font(.bzrMono(size: 9))
        .foregroundStyle(Color.txtTertiary)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Bottom card

private struct BottomCard: View {
  let title: String
  let sub: String
  let rows: [(String, String)]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.bzrTinyEyebrow)
          .tracking(1.6)
          .textCase(.uppercase)
          .foregroundStyle(Color.bzrLimeText)
        Text(sub)
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(.bottom, 4)
      ForEach(rows, id: \.0) { row in
        VStack(alignment: .leading, spacing: 2) {
          Text(row.0)
            .font(.bzrMono(size: 11, weight: .semibold))
            .foregroundStyle(Color.bzrLimeText)
          Text(row.1)
            .font(.bzrBody(size: 11))
            .foregroundStyle(Color.txtSecondary)
        }
        .padding(.vertical, 2)
      }
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
}
