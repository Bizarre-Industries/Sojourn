// Sojourn — PreferencesPane

import SwiftUI

struct PreferencesPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "PREFERENCES · defaults export/import · plutil xml1 · cfprefsd",
      title: "PREFERENCES.",
      subtitle: "Per-domain plist round-trip via PrefService. Discovery (which apps are configured) and per-domain diff land in v0.3 — until then this surface intentionally lists nothing rather than fake rows."
    )
    .accessibilityIdentifier("pane.preferences")
  }
}
