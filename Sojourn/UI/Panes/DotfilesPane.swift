// Sojourn — DotfilesPane

import SwiftUI

struct DotfilesPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "DOTFILES · ChezmoiService · age · per-host templates",
      title: "DOTFILES.",
      subtitle: "Per-file managed list with diff vs. chezmoi source. Wired to `chezmoi managed --format=json` + `chezmoi diff` in v0.3 — until then this surface intentionally lists nothing rather than fake rows."
    )
    .accessibilityIdentifier("pane.dotfiles")
  }
}
