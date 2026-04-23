import Foundation

/// Snapshot of which tools are installed and where. Populated by ToolLocator.
/// Value type, Sendable. See docs/ARCHITECTURE.md section 11.
struct ToolInventory: Sendable, Codable, Equatable {
  var brew: URL?
  var git: URL?
  var mpm: URL?
  var chezmoi: URL?
  var age: URL?
  var defaults: URL?
  var plutil: URL?
  var xattr: URL?
  var killall: URL?
  var xcodeCLT: Bool
  var gitleaksBundled: URL?

  static let empty = ToolInventory(xcodeCLT: false)
}
