import Foundation

/// Wraps defaults export/import and plutil -convert for app-preference
/// round-tripping through cfprefsd. See docs/ARCHITECTURE.md section 8.
actor PrefService {
  init() {}
}

/// Classification of a tracked preference domain.
/// See docs/ARCHITECTURE.md section 8 (Layer 2).
enum PreferenceClass: String, Sendable, Codable {
  case plainDotfile = "plain_dotfile"
  case unsandboxedPlist = "unsandboxed_plist"
  case sandboxedPlist = "sandboxed_plist"
  case applicationSupportBlob = "application_support_blob"
}
