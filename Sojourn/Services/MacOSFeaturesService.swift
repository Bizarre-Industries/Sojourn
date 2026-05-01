// Sojourn — MacOSFeaturesService (v0.2 step 7)
//
// First-class wrapper over `defaults` + a Touch-ID-for-sudo helper.
// Each toggle is reversible from the Generations pane (snapshot
// captures the relevant plist domains pre-op).
//
// Per docs/process/plans/v0.2-plan.md step 7. The full v0.2 surface:
//
//   - Touch ID for sudo                   (patches /etc/pam.d/sudo)
//   - Finder defaults                     (com.apple.finder + NSGlobal)
//   - Trackpad / keyboard repeat          (NSGlobalDomain)
//   - Screencapture location/format       (com.apple.screencapture)
//   - Login window text                   (com.apple.loginwindow)
//   - Dock persistent-apps editor         (deferred to v0.3 — drag UI heavy)
//   - Hotkey editor (symbolichotkeys)     (deferred to v0.3 — binary plist)
//
// Touch-ID PAM patch surfaces via osascript with `with administrator
// privileges` (Authorization Services prompt) in v0.2; a privileged
// helper at /Library/PrivilegedHelperTools/ ships in v0.3 per
// docs/process/plans/v0.2-plan.md §"Out of scope".

import Foundation

internal enum MacOSFeaturesError: Error, Sendable, CustomStringConvertible {
  case defaultsWriteFailed(domain: String, key: String, stderr: String)
  case defaultsReadFailed(domain: String, key: String, stderr: String)
  case helperScriptMissing(URL)
  case authorizationCancelled
  case launchAgentInstallFailed(String)

  internal var description: String {
    switch self {
    case .defaultsWriteFailed(let domain, let key, let stderr):
      return "defaults write \(domain) \(key) failed: \(stderr)"
    case .defaultsReadFailed(let domain, let key, let stderr):
      return "defaults read \(domain) \(key) failed: \(stderr)"
    case .helperScriptMissing(let url):
      return "Helper script missing at \(url.path)"
    case .authorizationCancelled:
      return "Authorization cancelled by user"
    case .launchAgentInstallFailed(let msg):
      return "LaunchAgent install failed: \(msg)"
    }
  }
}

/// Subset of Finder preferences Sojourn surfaces. Each maps to a
/// `defaults read/write com.apple.finder <key>` call.
internal enum FinderDefault: String, Sendable, CaseIterable, Identifiable {
  case showAllExtensions    = "AppleShowAllExtensions"
  case showPathbar          = "ShowPathbar"
  case showStatusBar        = "ShowStatusBar"
  case showHiddenFiles      = "AppleShowAllFiles"
  case sortFoldersFirst     = "_FXSortFoldersFirst"
  case preferredViewStyle   = "FXPreferredViewStyle"

  internal var id: String { rawValue }

  /// `defaults` domain. Most live under `com.apple.finder`; the
  /// extension-toggle is global.
  internal var domain: String {
    switch self {
    case .showAllExtensions: return "NSGlobalDomain"
    default:                 return "com.apple.finder"
    }
  }

  internal enum Kind { case bool, string }

  internal var kind: Kind {
    switch self {
    case .preferredViewStyle: return .string
    default:                  return .bool
    }
  }
}

internal actor MacOSFeaturesService {
  private let runner: SubprocessRunner
  private let defaultsURL: URL
  private let killallURL: URL
  private let osascriptURL: URL
  private let helperScriptURL: URL?
  private let fm: FileManager

  internal init(
    runner: SubprocessRunner,
    defaultsURL: URL = URL(fileURLWithPath: "/usr/bin/defaults"),
    killallURL: URL = URL(fileURLWithPath: "/usr/bin/killall"),
    osascriptURL: URL = URL(fileURLWithPath: "/usr/bin/osascript"),
    helperScriptURL: URL? = nil,
    fileManager: FileManager = .default
  ) {
    self.runner = runner
    self.defaultsURL = defaultsURL
    self.killallURL = killallURL
    self.osascriptURL = osascriptURL
    self.helperScriptURL = helperScriptURL
    self.fm = fileManager
  }

  // MARK: - defaults read/write primitives

  internal func readBool(domain: String, key: String) async throws -> Bool? {
    let result = try await runner.run(
      tool: defaultsURL,
      args: ["read", domain, key],
      timeout: 10
    )
    if result.exitCode != 0 { return nil }
    let text = result.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
    if text == "1" || text.caseInsensitiveCompare("YES") == .orderedSame
      || text.caseInsensitiveCompare("true") == .orderedSame {
      return true
    }
    if text == "0" || text.caseInsensitiveCompare("NO") == .orderedSame
      || text.caseInsensitiveCompare("false") == .orderedSame {
      return false
    }
    return nil
  }

  internal func writeBool(domain: String, key: String, value: Bool) async throws {
    let result = try await runner.run(
      tool: defaultsURL,
      args: ["write", domain, key, "-bool", value ? "true" : "false"],
      timeout: 10
    )
    if result.exitCode != 0 {
      throw MacOSFeaturesError.defaultsWriteFailed(
        domain: domain, key: key, stderr: result.stderrString
      )
    }
  }

  internal func readString(domain: String, key: String) async throws -> String? {
    let result = try await runner.run(
      tool: defaultsURL,
      args: ["read", domain, key],
      timeout: 10
    )
    if result.exitCode != 0 { return nil }
    return result.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  internal func writeString(domain: String, key: String, value: String) async throws {
    let result = try await runner.run(
      tool: defaultsURL,
      args: ["write", domain, key, "-string", value],
      timeout: 10
    )
    if result.exitCode != 0 {
      throw MacOSFeaturesError.defaultsWriteFailed(
        domain: domain, key: key, stderr: result.stderrString
      )
    }
  }

  internal func writeInt(domain: String, key: String, value: Int) async throws {
    let result = try await runner.run(
      tool: defaultsURL,
      args: ["write", domain, key, "-int", String(value)],
      timeout: 10
    )
    if result.exitCode != 0 {
      throw MacOSFeaturesError.defaultsWriteFailed(
        domain: domain, key: key, stderr: result.stderrString
      )
    }
  }

  // MARK: - Finder

  internal func setFinderDefault(_ key: FinderDefault, on: Bool) async throws {
    switch key.kind {
    case .bool:
      try await writeBool(domain: key.domain, key: key.rawValue, value: on)
    case .string:
      let v = on ? "Nlsv" : "icnv"
      try await writeString(domain: key.domain, key: key.rawValue, value: v)
    }
    _ = try? await runner.run(
      tool: killallURL, args: ["Finder"], timeout: 10
    )
  }

  internal func readFinderDefault(_ key: FinderDefault) async throws -> Bool? {
    switch key.kind {
    case .bool:
      return try await readBool(domain: key.domain, key: key.rawValue)
    case .string:
      let v = try await readString(domain: key.domain, key: key.rawValue)
      return v == "Nlsv"
    }
  }

  // MARK: - Keyboard repeat

  /// macOS encodes initial-key-repeat in 15 ms ticks. Apple's slowest
  /// slider is 120 (1800 ms); fastest is 15 (225 ms). Power users
  /// sometimes set 10 directly via defaults.
  internal func setKeyRepeat(initial: Int, repeatRate: Int) async throws {
    try await writeInt(
      domain: "NSGlobalDomain", key: "InitialKeyRepeat", value: initial
    )
    try await writeInt(
      domain: "NSGlobalDomain", key: "KeyRepeat", value: repeatRate
    )
  }

  // MARK: - Screencapture

  internal func setScreencaptureLocation(_ url: URL) async throws {
    try await writeString(
      domain: "com.apple.screencapture", key: "location", value: url.path
    )
    _ = try? await runner.run(
      tool: killallURL, args: ["SystemUIServer"], timeout: 10
    )
  }

  internal func setScreencaptureType(_ type: String) async throws {
    try await writeString(
      domain: "com.apple.screencapture", key: "type", value: type
    )
  }

  // MARK: - Login window

  internal func setLoginWindowText(_ text: String) async throws {
    try await writeString(
      domain: "/Library/Preferences/com.apple.loginwindow",
      key: "LoginwindowText",
      value: text
    )
  }

  // MARK: - Touch ID for sudo

  /// Edits `/etc/pam.d/sudo` to insert `auth sufficient pam_tid.so` on
  /// the second line via the helper script. Surfaces an
  /// AuthorizationServices prompt; user enters their password once
  /// per session.
  internal func enableTouchIDForSudo() async throws {
    guard let helper = helperScriptURL else {
      throw MacOSFeaturesError.helperScriptMissing(
        URL(fileURLWithPath: "Sojourn/Resources/scripts/touch-id-sudo.sh")
      )
    }
    if !fm.fileExists(atPath: helper.path) {
      throw MacOSFeaturesError.helperScriptMissing(helper)
    }
    let script = """
    do shell script "/bin/bash \(helper.path) enable" with administrator privileges
    """
    let result = try await runner.run(
      tool: osascriptURL,
      args: ["-e", script],
      timeout: 60
    )
    if result.exitCode != 0 {
      if result.exitCode == -128 || result.exitCode == 1 {
        throw MacOSFeaturesError.authorizationCancelled
      }
      throw MacOSFeaturesError.launchAgentInstallFailed(result.stderrString)
    }
  }

  /// Reads /etc/pam.d/sudo to determine whether the patch is currently
  /// applied. Read-only; no privilege required.
  internal nonisolated func isTouchIDForSudoEnabled() -> Bool {
    let pam = URL(fileURLWithPath: "/etc/pam.d/sudo")
    guard let text = try? String(contentsOf: pam, encoding: .utf8) else {
      return false
    }
    return text.contains("pam_tid.so")
  }
}
