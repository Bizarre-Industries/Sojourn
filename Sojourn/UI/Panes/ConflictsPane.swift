// Sojourn — ConflictsPane

import SwiftUI

struct ConflictsPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "CONFLICTS · SyncCoordinator · three-way merge",
      title: "CONFLICTS.",
      subtitle: "When two machines edit the same file between syncs, the resolution UI surfaces here. Cooperative writer lock means conflicts are rare; pull-resolves-before-push means they show up reliably when they do. The interactive resolver lands in v0.3."
    )
    .accessibilityIdentifier("pane.conflicts")
  }
}
