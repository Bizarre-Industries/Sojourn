// Sojourn — DotfilesPane

import SwiftUI

struct DotfilesPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "DOTFILES · ChezmoiService · age · per-host templates",
      title: "Dotfiles",
      subtitle: "Per-file managed list with diff vs. chezmoi source. This surface stays empty until managed-file data is available."
    )
    .accessibilityIdentifier("pane.dotfiles")
  }
}
