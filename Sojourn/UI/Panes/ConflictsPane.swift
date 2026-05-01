// Sojourn — ConflictsPane

import SwiftUI

struct ConflictsPane: View {
  private struct Shape: Identifiable {
    let id: String
    let title: String
    let context: String
    let resolution: String
  }

  private var shapes: [Shape] {
    [
      .init(id: "1", title: "TEXT EDIT", context: ".zshrc edited on both Macs", resolution: "Keep local · Keep remote · Manual merge"),
      .init(id: "2", title: "PACKAGES.TOML", context: "mpm install/remove diverged", resolution: "Merge per-manager (grouped UI)"),
      .init(id: "3", title: "CHEZMOI TEMPLATE", context: "dot_gitconfig.tmpl conditional clash", resolution: "Always surfaces · cannot auto-merge Go templates"),
      .init(id: "4", title: "PLIST", context: "iterm2 same key, different values", resolution: "Keyed diff · per-key pick"),
      .init(id: "5", title: "RENAME × EDIT", context: ".tmux.conf renamed + edited", resolution: "User picks final path · git rename hint"),
      .init(id: "6", title: "DELETE × EDIT", context: "chezmoi forget vs continued edit", resolution: "Default: keep edit · explicit override")
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
