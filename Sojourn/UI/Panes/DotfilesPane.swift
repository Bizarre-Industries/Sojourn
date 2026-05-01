// Sojourn — DotfilesPane

import SwiftUI

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
      .init(id: ".zshrc", mark: "M", path: ".zshrc", kind: "modified", meta: "4 lines"),
      .init(id: ".gitconfig", mark: "M", path: ".gitconfig", kind: "modified", meta: "1 line"),
      .init(id: ".config/nvim/init.lua", mark: "A", path: ".config/nvim/init.lua", kind: "added", meta: "+47 −0"),
      .init(id: ".tmux.conf", mark: "M", path: ".tmux.conf", kind: "modified", meta: "2 lines"),
      .init(id: ".config/starship.toml", mark: " ", path: ".config/starship.toml", kind: "clean", meta: nil),
      .init(id: ".config/wezterm/wezterm.lua", mark: " ", path: ".config/wezterm/wezterm.lua", kind: "clean", meta: nil),
      .init(id: ".aws/config", mark: " ", path: ".aws/config", kind: "encrypted", meta: "age"),
      .init(id: ".config/git/ignore", mark: " ", path: ".config/git/ignore", kind: "clean", meta: nil),
      .init(id: ".npmrc", mark: " ", path: ".npmrc", kind: "template", meta: "{{.host}}"),
      .init(id: ".config/karabiner/", mark: " ", path: ".config/karabiner/", kind: "clean", meta: "12 files")
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
    case "M": return Color(red: 255 / 255, green: 184 / 255, blue: 74 / 255)
    case "A": return Color(red: 108 / 255, green: 230 / 255, blue: 124 / 255)
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
          BzrBadge(text: "MODIFIED", kind: .tierC)
          BzrBadge(text: "SOURCE · dot_zshrc.tmpl", kind: .mute)
          BzrBadge(text: "+4 −1", kind: .mute)
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
      .init(kind: .hunk, lineNum: "", text: "@@ -42,7 +42,10 @@ # path additions"),
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
        .foregroundStyle(Color(red: 155 / 255, green: 196 / 255, blue: 255 / 255))
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
    case .add: return Color(red: 184 / 255, green: 240 / 255, blue: 192 / 255)
    case .rem: return Color(red: 255 / 255, green: 184 / 255, blue: 188 / 255)
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
