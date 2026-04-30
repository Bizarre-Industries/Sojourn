// SyncMergeTargetTests — exercises the chezmoi-status parser that
// drives audit §2.2.3 three-way merge for text dotfiles.

import Foundation
import Testing
@testable import Sojourn

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
}
