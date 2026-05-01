// Sojourn — SecretsPane

import SwiftUI

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
          Stat(label: "Last scan", value: "2", unit: "hours", kind: .neutral, meta: "a3f9c2e · pre-commit"),
          Stat(label: "Findings", value: "0", unit: nil, kind: .lime, meta: "since last push"),
          Stat(label: "Allowlisted", value: "2", unit: nil, kind: .neutral, meta: "test fixtures · repo-scoped"),
          Stat(label: "Rules", value: "142", unit: nil, kind: .neutral, meta: ".gitleaks.toml · bundled")
        ])

        Text("Last scan output")
          .font(.bzrDetailH2)
          .foregroundStyle(Color.txtPrimary)
          .padding(.top, 6)

        VStack(alignment: .leading, spacing: 0) {
          scanLogLine("14:21:58", "$", "gitleaks dir --staged --no-git --report-format json", .secondary)
          scanLogLine("14:21:58", "→", "scanning 47 staged files (4.2 MB)", .lime)
          scanLogLine("14:21:59", "✓", "rule set: 142 patterns loaded from .gitleaks.toml", .ok)
          scanLogLine("14:22:00", "✓", "dotfiles/dot_zshrc.tmpl    clean", .ok)
          scanLogLine("14:22:00", "✓", "dotfiles/dot_gitconfig.tmpl clean", .ok)
          scanLogLine("14:22:01", "⚠", "packages.toml:42  generic-api-key  → ALLOWLISTED (repo)", .warn)
          scanLogLine("14:22:01", "✓", "47 files scanned, 0 findings, 2 allowlisted", .ok)
          scanLogLine("14:22:01", "━", "commit allowed. proceeding to push.", .lime)
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
        .foregroundStyle(Color(red: 220 / 255, green: 225 / 255, blue: 210 / 255).opacity(0.85))
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
