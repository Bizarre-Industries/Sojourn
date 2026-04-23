import Foundation

/// Resolves tool paths by probing hardcoded candidate locations.
/// App-context PATH is LaunchServices-minimal; which(1) fails for brew
/// on Apple Silicon. See docs/ARCHITECTURE.md section 9 (Detection).
actor ToolLocator {
  init() {}

  static let candidatePaths: [String: [String]] = [
    "brew": ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"],
    "git": ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"],
    "mpm": [
      "/opt/homebrew/bin/mpm",
      "/usr/local/bin/mpm",
      "~/Library/Application Support/Sojourn/bin/mpm",
    ],
    "chezmoi": ["/opt/homebrew/bin/chezmoi", "/usr/local/bin/chezmoi"],
    "age": ["/opt/homebrew/bin/age", "/usr/local/bin/age"],
    "defaults": ["/usr/bin/defaults"],
    "plutil": ["/usr/bin/plutil"],
    "xattr": ["/usr/bin/xattr"],
    "killall": ["/usr/bin/killall"],
  ]
}
