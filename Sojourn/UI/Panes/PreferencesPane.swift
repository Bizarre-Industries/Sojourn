// Sojourn — PreferencesPane

import SwiftUI

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
      .init(id: "com.googlecode.iterm2", name: "iTerm2", scope: "unsandboxed", mark: "M", format: "XML"),
      .init(id: "com.apple.dock", name: "Dock", scope: "unsandboxed", mark: "M", format: "XML"),
      .init(id: "com.apple.finder", name: "Finder", scope: "unsandboxed", mark: " ", format: "XML"),
      .init(id: "com.raycast.macos", name: "Raycast", scope: "unsandboxed", mark: " ", format: "XML"),
      .init(id: "com.knollsoft.Rectangle", name: "Rectangle", scope: "unsandboxed", mark: " ", format: "XML"),
      .init(id: "org.pqrs.Karabiner-Elements", name: "Karabiner", scope: "app-supp", mark: "M", format: "JSON"),
      .init(id: "com.agilebits.onepassword4", name: "1Password 7", scope: "sandboxed", mark: " ", format: "FDA"),
      .init(id: "com.apple.Safari", name: "Safari", scope: "sandboxed", mark: " ", format: "FDA"),
      .init(id: "com.apple.TextEdit", name: "TextEdit", scope: "unsandboxed", mark: " ", format: "XML"),
      .init(id: "com.apple.Terminal", name: "Terminal", scope: "unsandboxed", mark: " ", format: "XML")
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
          .foregroundStyle(d.mark == "M" ? Color(red: 255 / 255, green: 184 / 255, blue: 74 / 255) : Color.txtSecondary)
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
          BzrBadge(text: "MODIFIED", kind: .tierC)
          BzrBadge(text: "XML · 47KB", kind: .mute)
          BzrBadge(text: "214 KEYS", kind: .mute)
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
            layerRow("user", "~/Library/Preferences/com.<app>.plist", .lime, "default", .lime)
            layerRow("system", "/Library/Preferences/com.<app>.plist", .ok, "root", .mute)
            layerRow("sandboxed", "~/Library/Containers/<bundle>/Data/Library/Preferences/", .warn, "FDA", .warn)
            layerRow("apple-internal", "non-standard, undocumented", .danger, "skip", .danger)
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
