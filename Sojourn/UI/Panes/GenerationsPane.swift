// Sojourn — GenerationsPane

import SwiftUI

struct GenerationsPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "GENERATIONS · ~/Library/Application Support/Sojourn/generations/",
      title: "GENERATIONS.",
      subtitle: "Git-tagged tarball snapshots of Brewfile + chezmoi source + plist exports. Every destructive op writes one before touching the working tree. The list, diff, and rollback land in v0.3 — until then this surface intentionally lists nothing rather than fake rows."
    )
    .accessibilityIdentifier("pane.generations")
  }
}
