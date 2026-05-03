// Sojourn — DiagnosticsPane

import SwiftUI

struct DiagnosticsPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "DIAGNOSTICS · DiagnosticBundle · log domains",
      title: "DIAGNOSTICS.",
      subtitle: "Per-domain log counters (sync, subprocess, bootstrap, secrets, cleanup, ui) + diagnostic-bundle export. Counters wire to SojournLog in v0.3 — until then this surface intentionally shows nothing rather than fake numbers."
    )
    .accessibilityIdentifier("pane.diagnostics")
  }
}
