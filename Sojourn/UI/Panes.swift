// Sojourn — Panes
//
// Twelve detail panes hang off the main window's Liquid Glass shell.
// Each pane reads @Environment(AppStore.self) for live state. Stage 3
// fills empty panes with the design's full content; Stage 2 establishes
// stubs so the chrome compiles end-to-end.
//
// See docs/reference/architecture.md §11.

import SwiftUI

// MARK: - Carry · Overview (Stage 2 stub; Stage 3 fills it)

struct OverviewPane: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        EyebrowLabel(text: "BIZARRE / CARRY / OVERVIEW")
          .padding(.top, 8)
        Text("Catch the stars.")
          .font(.bzrDetailH1)
          .foregroundStyle(Color.txtPrimary)
        Text("Three carry surfaces, one bench. Packages, dotfiles, preferences.")
          .font(.bzrBody(size: 14))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 560, alignment: .leading)
        StatStrip(stats: [
          Stat(label: "Packages", value: "184", unit: "managed", kind: .lime),
          Stat(label: "Dotfiles", value: "32",  unit: "files",   kind: .neutral),
          Stat(label: "Prefs",    value: "18",  unit: "domains", kind: .neutral)
        ])
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.overview")
  }
}

// MARK: - Sync · Conflicts (six shapes)

struct ConflictsPane: View {
  var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "SYNC / CONFLICTS",
        title: "Six shapes.",
        subtitle: "Conflicts surface here after a pull. Each shape has its own resolution path — none auto-merge in v1."
      )
    ) {
      conflictShape("1 · text",      "chezmoi merge against $merge.command. Default: opendiff → kdiff3 → vimdiff.", .info)
      conflictShape("2 · binary",    "Side-by-side preview, keep one or both. apply --force only after explicit confirm.", .warn)
      conflictShape("3 · plist",     "plutil-converted XML diff. Dictionary keys merged by Sojourn; arrays kept atomic.", .info)
      conflictShape("4 · prefs",     "Per-domain plist drift. App is alive → quit prompt → defaults import → relaunch.", .warn)
      conflictShape("5 · cooldown",  "Local install during cooldown window. Bypass requires advisory hit OR explicit override.", .warn)
      conflictShape("6 · advisory",  "OSV/GHSA hit on installed package. Cooldown bypassed; user picks update or pin.", .danger)
    }
    .accessibilityIdentifier("pane.conflicts")
  }

  @ViewBuilder
  private func conflictShape(_ title: String, _ body: String, _ kind: BzrCalloutKind) -> some View {
    BzrCallout(title: title, kind: kind, bodyText: body)
  }
}

// MARK: - First-run · Onboard new machine

struct OnboardPane: View {
  var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "FIRST RUN / ONBOARD",
        title: "Add another Mac.",
        subtitle: "Three steps: GitHub Device Flow auth, age recipient generation, take-writer-lock from the previous machine."
      )
    ) {
      BzrCard(title: "Step 1 — GitHub Device Flow", eyebrow: "AUTH") {
        VStack(alignment: .leading, spacing: 10) {
          Text("Sojourn opens https://github.com/login/device and shows you an 8-character code. No client_secret embedded; no browser redirects.")
            .font(.bzrBody(size: 12))
            .foregroundStyle(Color.txtSecondary)
          BzrCodeBlock(text: "device_code: WDJB-MJHT")
        }
      }

      BzrCard(title: "Step 2 — age recipient", eyebrow: "ENCRYPTION") {
        VStack(alignment: .leading, spacing: 10) {
          Text("Generate an age key locally. The public recipient gets added to .sojourn/recipients.txt; previous machines re-encrypt secrets for it.")
            .font(.bzrBody(size: 12))
            .foregroundStyle(Color.txtSecondary)
          BzrCodeBlock(text: """
            age-keygen -o ~/.config/sojourn/age.key
            # public: age1qpgmt7n3dl6jxs9c2dp...
            """)
        }
      }

      BzrCard(title: "Step 3 — take writer lock", eyebrow: "COORDINATION") {
        Text("The previous machine writes .sojourn/active.toml = this-mac. Cooperative — git doesn't enforce. Pull resolves before the new machine can push.")
          .font(.bzrBody(size: 12))
          .foregroundStyle(Color.txtSecondary)
      }

      BzrCallout(
        title: "Stage 14",
        kind: .info,
        bodyText: "Real device-flow + age recipient pipeline lands in Stage 14 with the SecretBroker abstraction."
      )
    }
    .accessibilityIdentifier("pane.onboard")
  }
}

// MARK: - Hygiene · Secrets

struct SecretsPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "HYGIENE / SECRETS",
        title: "gitleaks watch.",
        subtitle: "Bundled gitleaks scans every push. High-confidence findings (AWS / GitHub PAT / OpenAI / Stripe) trigger a 5-second lockout sheet."
      )
    ) {
      StatStrip(stats: [
        Stat(label: "Last scan", value: "0",  unit: "findings", kind: .lime),
        Stat(label: "Rules",     value: "—",  unit: "active",   kind: .neutral),
        Stat(label: "Allowlist", value: "0",  unit: "entries",  kind: .neutral)
      ])

      BzrCard(title: "Bundled binary", eyebrow: "BACKEND") {
        VStack(alignment: .leading, spacing: 8) {
          Text("Sojourn ships gitleaks under Contents/Resources/bin, re-signed with the hardened runtime at build time.")
            .font(.bzrBody(size: 12))
            .foregroundStyle(Color.txtSecondary)
          BzrCodeBlock(text: "gitleaks dir --staged --report-format json --config=.gitleaks.toml")
        }
      }

      BzrCallout(
        title: "5-second lockout",
        kind: .warn,
        bodyText: "When a high-confidence provider key (aws-access-token, github-pat, openai-api-key, stripe-access-token) appears, the bypass button is disabled for 5 seconds. Forces the user to read."
      )

      BzrCallout(
        title: "Stage 14",
        kind: .info,
        bodyText: "Custom rules editor, allowlist with regex tester, and the SecretBroker tab (1Password / Bitwarden / Keychain / age) land in Stage 14."
      )
    }
    .accessibilityIdentifier("pane.secrets")
  }
}

// MARK: - App · Diagnostics

struct DiagnosticsPane: View {
  @Environment(AppStore.self) private var store
  @State private var redactionEnabled: Bool = true

  var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "APP / DIAGNOSTICS",
        title: "Diagnostics.",
        subtitle: "Tool inventory, OSLog stream, redactor, export bundle. Stage 8 wires the redactor; Stage 11 embeds chezmoi doctor."
      )
    ) {
      BzrCard(title: "Tool inventory", eyebrow: "BOOTSTRAP") {
        VStack(alignment: .leading, spacing: 6) {
          toolRow("git",     "/usr/bin/git",                 .ok)
          toolRow("brew",    "/opt/homebrew/bin/brew",       .ok)
          toolRow("mpm",     "/opt/homebrew/bin/mpm",        .lime)
          toolRow("chezmoi", "/opt/homebrew/bin/chezmoi",    .lime)
          toolRow("age",     "<bundled>/Contents/Resources/bin/age", .ok)
          toolRow("gitleaks","<bundled>/Contents/Resources/bin/gitleaks", .ok)
        }
      }

      BzrCard(title: "Redaction", eyebrow: "EXPORT BUNDLE") {
        HStack {
          Text("Strip user paths and secrets from logs before export")
            .font(.bzrBody(size: 12))
            .foregroundStyle(Color.txtSecondary)
          Spacer()
          BzrToggle(isOn: $redactionEnabled)
        }
      }

      BzrCallout(
        title: "Stage 8 + 11",
        kind: .info,
        bodyText: "OSLog tail, the Diagnostics/Redactor module, and chezmoi doctor wiring land in Stage 8 (module split) and Stage 11 (chezmoi gap)."
      )
    }
    .accessibilityIdentifier("pane.diagnostics")
  }

  @ViewBuilder
  private func toolRow(_ name: String, _ path: String, _ kind: StatusDotKind) -> some View {
    HStack {
      StatusDot(kind: kind)
      Text(name)
        .font(.bzrBody(size: 12, weight: .semibold))
        .foregroundStyle(Color.txtPrimary)
        .frame(width: 80, alignment: .leading)
      Text(path)
        .font(.bzrCode)
        .foregroundStyle(Color.txtSecondary)
      Spacer()
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

// MARK: - Carry · Packages

struct PackagesPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "CARRY / PACKAGES",
        title: "Packages.",
        subtitle: "Twelve managers via mpm. Cooldown gate in front of every install. Advisory bypass on OSV/GHSA hits."
      )
    ) {
      let total = store.managers.values.map { $0.packages.count }.reduce(0, +)
      let outdated = store.managers.values
        .flatMap { $0.packages }
        .filter { $0.installedVersion != nil && $0.installedVersion != ($0.latestVersion ?? "") && $0.latestVersion != nil }
        .count

      StatStrip(stats: [
        Stat(label: "Total",    value: "\(total)",     unit: "packages",  kind: .lime),
        Stat(label: "Outdated", value: "\(outdated)",  unit: "to update", kind: outdated > 0 ? .warn : .neutral),
        Stat(label: "Managers", value: "\(store.managers.count)", unit: "active", kind: .neutral)
      ])

      if store.managers.isEmpty {
        BzrCallout(
          title: "No managers detected",
          kind: .warn,
          bodyText: "Run Bootstrap to install meta-package-manager. mpm is the canonical entry point — it wraps brew, cask, mas, npm, pip, and the rest."
        )
      } else {
        ForEach(Array(store.managers.keys.sorted()), id: \.self) { manager in
          if let snap = store.managers[manager] {
            BzrCard(title: snap.name.isEmpty ? manager : snap.name, eyebrow: "MANAGER · \(manager)") {
              VStack(alignment: .leading, spacing: 6) {
                ForEach(snap.packages.prefix(8)) { pkg in
                  HStack {
                    Text(pkg.name ?? pkg.id)
                      .font(.bzrBody(size: 12))
                      .foregroundStyle(Color.txtPrimary)
                    Spacer()
                    Text(pkg.installedVersion ?? "—")
                      .font(.bzrMono(size: 10))
                      .foregroundStyle(Color.txtTertiary)
                    BzrBadge(text: manager.uppercased(), kind: .mute)
                  }
                }
                if snap.packages.count > 8 {
                  Text("+ \(snap.packages.count - 8) more")
                    .font(.bzrMono(size: 10))
                    .foregroundStyle(Color.txtTertiary)
                }
              }
            }
          }
        }
      }
    }
    .accessibilityIdentifier("pane.packages")
  }
}

// MARK: - Carry · Dotfiles

struct DotfilesPane: View {
  var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "CARRY / DOTFILES",
        title: "Dotfiles.",
        subtitle: "chezmoi templates · age encryption · per-machine overrides. Externals (oh-my-zsh, prezto, lazy.nvim) pull on every chezmoi update."
      )
    ) {
      BzrCard(title: "chezmoi commands", eyebrow: "BACKEND") {
        BzrCodeBlock(text: """
          chezmoi managed --format=json
          chezmoi status
          chezmoi diff --no-pager --color=false
          chezmoi merge <path>      # text dotfiles, three-way
          chezmoi apply --force     # binaries / plists only
          chezmoi update            # refresh externals
          """)
      }

      BzrCallout(
        title: "Stage 11",
        kind: .info,
        bodyText: "Externals, run-scripts, unmanaged tab, forget action, doctor, state controls, password-manager template funcs, and the .chezmoiignore boilerplate land in Stage 11."
      )
    }
    .accessibilityIdentifier("pane.dotfiles")
  }
}

// MARK: - Carry · Preferences

struct PreferencesPane: View {
  var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "CARRY / PREFERENCES",
        title: "App Preferences.",
        subtitle: "Four plist layers: user, system, sandboxed (FDA-gated), apple-internal. Round-tripped via defaults export / defaults import."
      )
    ) {
      BzrCard(title: "Plist layers", eyebrow: "DEFAULTS") {
        VStack(alignment: .leading, spacing: 10) {
          plistRow("user", "~/Library/Preferences/com.<app>.plist", .lime, "default")
          plistRow("system", "/Library/Preferences/com.<app>.plist", .ok, "root")
          plistRow("sandboxed", "~/Library/Containers/<bundle>/Data/Library/Preferences/", .warn, "FDA")
          plistRow("apple-internal", "non-standard, undocumented", .danger, "skip")
        }
      }

      BzrCallout(
        title: "FDA canary",
        kind: .warn,
        bodyText: "Sojourn probes /Library/Preferences/com.apple.TimeMachine.plist on first launch to detect Full Disk Access. Without it, sandboxed plists are skipped."
      )
    }
    .accessibilityIdentifier("pane.preferences")
  }

  @ViewBuilder
  private func plistRow(_ layer: String, _ path: String, _ kind: StatusDotKind, _ tag: String) -> some View {
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
      BzrBadge(text: tag, kind: tag == "FDA" ? .warn : (tag == "skip" ? .danger : .mute))
    }
  }
}

// MARK: - Sync · History

struct HistoryPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "SYNC / HISTORY",
        title: "Timeline.",
        subtitle: "Every sync, install, and cleanup lands here. SQLite-backed (Stage 9); 30-day retention."
      )
    ) {
      if store.history.isEmpty {
        BzrCallout(
          title: "No entries yet",
          kind: .info,
          bodyText: "First push appears once you configure a remote in Settings → Sync."
        )
      } else {
        BzrCard(eyebrow: "ENTRIES · \(store.history.count)") {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(store.history.reversed().prefix(40)) { entry in
              HStack(alignment: .top, spacing: 10) {
                BzrBadge(text: entry.kind.rawValue, kind: .mute)
                VStack(alignment: .leading, spacing: 2) {
                  Text(entry.description)
                    .font(.bzrBody(size: 12))
                    .foregroundStyle(Color.txtPrimary)
                  Text(entry.timestamp.formatted(.relative(presentation: .named)))
                    .font(.bzrMono(size: 10))
                    .foregroundStyle(Color.txtTertiary)
                }
                Spacer()
              }
            }
          }
        }
      }
    }
    .accessibilityIdentifier("pane.history")
  }
}

// MARK: - Sync · Machines

struct MachinesPane: View {
  var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "SYNC / MACHINES",
        title: "Fleet.",
        subtitle: "One writer at a time. .sojourn/active.toml is a cooperative lock — git doesn't enforce. Pull resolves before push."
      )
    ) {
      BzrCard(title: Host.current().localizedName ?? "this-mac", eyebrow: "ACTIVE WRITER") {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            StatusDot(kind: .lime)
            Text("ACTIVE")
              .font(.bzrTinyEyebrow)
              .tracking(1.6)
              .foregroundStyle(Color.bzrLime)
            Spacer()
            BzrBadge(text: "WRITER", kind: .lime)
          }
          Text("Last activity 2h ago · ↑ a3f9c2e")
            .font(.bzrMono(size: 11))
            .foregroundStyle(Color.txtSecondary)
        }
      }

      BzrCallout(
        title: "Stage 9",
        kind: .info,
        bodyText: "Per-machine identity, overrides, and recipient list will populate once MachineMetadata + version.toml lands in Stage 9."
      )
    }
    .accessibilityIdentifier("pane.machines")
  }
}

// MARK: - Hygiene · Cleanup

struct CleanupPane: View {
  @Environment(AppStore.self) private var store
  @State private var scanning = false

  var body: some View {
    PaneScaffold(
      hero: PaneHero(
        eyebrow: "HYGIENE / CLEANUP",
        title: "Orphans.",
        subtitle: "Files belonging to apps no longer installed. Always Trash, never rm. APFS atime is unreliable."
      )
    ) {
      HStack {
        Button(scanning ? "Scanning…" : "Scan ~/Library") {
          Task {
            scanning = true
            await store.rescanOrphans()
            scanning = false
          }
        }
        .buttonStyle(GlassPrimaryButtonStyle())
        .disabled(scanning)
        .accessibilityIdentifier("pane.cleanup.scan")

        Text("\(store.orphans.count) candidate(s)")
          .font(.bzrMono(size: 11))
          .foregroundStyle(Color.txtTertiary)

        Spacer()
      }

      if store.orphans.isEmpty {
        BzrCallout(
          title: "No orphans",
          kind: .info,
          bodyText: "Press Scan to walk ~/Library. Files owned by uninstalled apps surface as candidates with classification (safe / review / risky)."
        )
      } else {
        BzrCard(eyebrow: "CANDIDATES · \(store.orphans.count)") {
          VStack(alignment: .leading, spacing: 6) {
            ForEach(store.orphans) { candidate in
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(candidate.path.lastPathComponent)
                    .font(.bzrBody(size: 12))
                    .foregroundStyle(Color.txtPrimary)
                  Text(candidate.reason)
                    .font(.bzrMono(size: 10))
                    .foregroundStyle(Color.txtTertiary)
                }
                Spacer()
                BzrBadge(text: candidate.category.rawValue, kind: badgeKind(for: candidate.category))
                Button("Trash") {
                  Task { try? await store.cleanup.trash(candidate) }
                }
                .buttonStyle(GlassDangerButtonStyle())
              }
            }
          }
        }
      }
    }
    .accessibilityIdentifier("pane.cleanup")
  }

  private func badgeKind(for c: OrphanCandidate.Category) -> BzrBadgeKind {
    switch c {
    case .safe:   return .success
    case .review: return .warn
    case .risky:  return .danger
    }
  }
}
