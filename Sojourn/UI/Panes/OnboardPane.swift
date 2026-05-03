// Sojourn — OnboardPane

import SwiftUI

struct OnboardPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "ONBOARD · BootstrapService · GitHubDeviceAuth",
      title: "ONBOARD A NEW MAC.",
      subtitle: "First-run flow lives in the BootstrapView sheet (auto-presented when bootstrap state is not .ready). Adding additional Macs to an existing fleet — generate age identity, print public recipient, share with writer, pull initial state — lands as a guided wizard in v0.3."
    )
    .accessibilityIdentifier("pane.onboard")
  }
}
