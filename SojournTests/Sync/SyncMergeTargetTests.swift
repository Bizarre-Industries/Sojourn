// SyncMergeTargetTests — exercises the chezmoi-status parser that
// drives audit §2.2.3 three-way merge for text dotfiles.

import Foundation
@testable import Sojourn
import Testing

@Suite("SyncCoordinator.textMergeTargets")
struct SyncMergeTargetTests {
  @Test("yields modified text paths and skips non-mergeable extensions")
  func filtersBinariesAndPlists() {
    let status = """
    MM .zshrc
     M .config/git/config
    MM logo.png
    MM Library/Preferences/com.apple.dock.plist
    A  newfile.txt
    """
    let targets = SyncCoordinator.textMergeTargets(fromStatus: status)
    #expect(targets.contains(".zshrc"))
    #expect(targets.contains(".config/git/config"))
    #expect(!targets.contains("logo.png"))
    #expect(!targets.contains("Library/Preferences/com.apple.dock.plist"))
    // A=added, not modified — skipped because parser requires `M` in
    // either column.
    #expect(!targets.contains("newfile.txt"))
  }

  @Test("empty status yields empty list")
  func emptyStatus() {
    #expect(SyncCoordinator.textMergeTargets(fromStatus: "").isEmpty)
  }

  @Test func pullReviewAccessibilityLabelsIncludeExactItems() {
    let review = PullApplyReview(
      chezmoiScripts: ["dotfiles/run_once_install.sh"],
      chezmoiTemplates: ["dot_config/app/config.toml.tmpl"],
      packageReviews: [
        PullPackageReview(
          brewfile: "Brewfile.common",
          manager: "cask",
          package: "arc",
          reason: "Homebrew entries can run install or postinstall steps."
        )
      ],
      omittedPackageReviewCount: 2
    )

    #expect(review.summary.contains("3 Brewfile"))
    #expect(review.summary.contains("1 chezmoi template"))
    #expect(review.accessibilitySummary.contains("Pull apply review required"))
    #expect(review.packageReviews[0].accessibilityLabel.contains("cask arc"))
  }
}
