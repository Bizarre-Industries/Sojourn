// Sojourn — DiagnosticsPane

import SwiftUI

struct DiagnosticsPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "DIAGNOSTICS · DiagnosticBundle · log domains",
      title: "Diagnostics",
      subtitle: "Per-domain log counters and diagnostic-bundle export state."
    )
    .accessibilityIdentifier("pane.diagnostics")
  }
}
