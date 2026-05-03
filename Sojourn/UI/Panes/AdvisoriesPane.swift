// Sojourn — AdvisoriesPane

import SwiftUI

struct AdvisoriesPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "ADVISORIES · AdvisoryService · brew vulns · OSV / GHSA",
      title: "ADVISORIES.",
      subtitle: "Cross-ecosystem CVE feed via `brew vulns`. The list, severity filter, and bypass-cooldown action land in v0.3 once AdvisoryService parses the OSV-format JSON — until then this surface intentionally lists nothing rather than fake CVE rows."
    )
    .accessibilityIdentifier("pane.advisories")
  }
}
