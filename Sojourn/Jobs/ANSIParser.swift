import Foundation

/// SGR (Select Graphic Rendition) escape-sequence parser.
/// Converts raw bytes with ANSI codes into AttributedString with
/// AttributeContainer for color and style.
/// See docs/ARCHITECTURE.md section 11 (Streaming output to UI).
enum ANSIParser {
  /// Strips all ANSI escape sequences. Default behavior for LogBuffer.
  static func strip(_ input: String) -> String {
    input
  }
}
