// Sojourn — DiagnosticsPane

import SwiftUI

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
      .init(id: "sync", count: "142", meta: "last 24h"),
      .init(id: "subprocess", count: "3,481", meta: "line-buffered"),
      .init(id: "bootstrap", count: "12", meta: "probe + install"),
      .init(id: "secrets", count: "7", meta: "gitleaks runs"),
      .init(id: "cleanup", count: "4", meta: "trash actions"),
      .init(id: "ui", count: "61", meta: "interaction")
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
          osLogLine("14:30:01", "[sync.info]", "SyncCoordinator.push begin · 3 candidates", .secondary)
          osLogLine("14:30:01", "[subprocess.debug]", "/usr/bin/git status --porcelain=v2 --branch -z", .secondary)
          osLogLine("14:30:02", "[secrets.info]", "gitleaks dir --staged --no-git --report-format json", .secondary)
          osLogLine("14:30:03", "[secrets.info]", "0 findings · 2 allowlisted · 47 files", .ok)
          osLogLine("14:30:03", "[subprocess.debug]", "/usr/bin/tar -czf backups/2026-04-28T14-30-pre-push.tgz dotfiles preferences", .secondary)
          osLogLine("14:30:05", "[subprocess.debug]", "/usr/bin/git commit -s -m \"install ripgrep, fd, eza · iterm2 prefs\"", .secondary)
          osLogLine("14:30:05", "[subprocess.debug]", "/usr/bin/git push origin main", .secondary)
          osLogLine("14:30:07", "[sync.info]", "push ok · a3f9c2e → origin/main", .ok)
          osLogLine("14:30:07", "[ui.error]", "AppleScript quit timed out for com.googlecode.iterm2 (5s)", .warn)
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
        .foregroundStyle(Color(red: 220 / 255, green: 225 / 255, blue: 210 / 255).opacity(0.85))
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
      toolRowExt("xcode-select", "/usr/bin/xcode-select", "CLT 16.2", .ok)
      toolRowExt("git", "/usr/bin/git", "2.42.1 · system", .ok)
      toolRowExt("brew", "/opt/homebrew/bin/brew", "4.4.7 · Apple-Silicon", .ok)
      toolRowExt("brew", "/opt/homebrew/bin/brew", "5.x · brew bundle dump/install", .ok)
      toolRowExt("chezmoi", "/opt/homebrew/bin/chezmoi", "2.70.2 · brew", .ok)
      toolRowExt("gitleaks", "…/Resources/bin/gitleaks", "8.30.1 · bundled · MIT", .lime)
      toolRowExt("age", "…/Resources/bin/age", "1.2.0 · bundled · MIT", .lime)
      toolRowExt("npm", "~/.npm-global/bin/npm", "— · on-demand · brew install node", .secondary)
      toolRowExt("pnpm", "—", "— · v2 deferred · not in Brewfile grammar", .secondary)
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
