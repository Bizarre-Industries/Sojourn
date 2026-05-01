// Sojourn — OnboardPane

import SwiftUI

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
      .init(id: "1", label: "PROBE", detail: "Found brew, mpm, chezmoi, git, age", state: .done),
      .init(id: "2", label: "REMOTE", detail: "git@github.com:you/my-mac.git · clone ok", state: .done),
      .init(id: "3", label: "MACHINE ID", detail: "mini-home.local · 8d2a-... · stored", state: .done),
      .init(id: "4", label: "AGE IDENTITY", detail: "Generated · public recipient ready to share", state: .active),
      .init(id: "5", label: "WRITER ADDS", detail: "Old Mac re-encrypts on next push", state: .pending),
      .init(id: "6", label: "PULL", detail: "mpm restore + chezmoi apply + defaults import", state: .pending),
      .init(id: "7", label: "READY", detail: "Reader joined fleet", state: .pending)
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
