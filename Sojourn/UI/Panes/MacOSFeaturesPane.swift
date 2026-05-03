// Sojourn — MacOSFeaturesPane

import SwiftUI

struct MacOSFeaturesPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "MACOS FEATURES · MacOSFeaturesService · defaults / plutil / launchctl",
      title: "MACOS FEATURES.",
      subtitle: "First-class toggles for Touch ID-for-sudo, dock layout, Finder defaults, keyboard repeat, screencapture format, login-window text. Each feature lands as it's wired to MacOSFeaturesService — the surface is intentionally empty until then rather than showing fake toggles."
    )
    .accessibilityIdentifier("pane.macos-features")
  }
}
