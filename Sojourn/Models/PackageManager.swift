import Foundation

/// Canonical list of package managers Sojourn knows about.
/// See docs/ARCHITECTURE.md section 5.1 for mpm-supported ids.
enum PackageManager: String, CaseIterable, Sendable, Codable {
  case brew
  case cask
  case mas
  case pip
  case pipx
  case npm
  case gem
  case composer
  case cargo
  case yarn
  case vscode
  case uvx

  var displayName: String {
    switch self {
    case .brew: return "Homebrew"
    case .cask: return "Homebrew Cask"
    case .mas: return "Mac App Store"
    case .pip: return "pip"
    case .pipx: return "pipx"
    case .npm: return "npm"
    case .gem: return "RubyGems"
    case .composer: return "Composer"
    case .cargo: return "Cargo"
    case .yarn: return "Yarn"
    case .vscode: return "VS Code extensions"
    case .uvx: return "uvx"
    }
  }
}
