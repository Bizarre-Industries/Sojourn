// Sojourn — ANSIParser
//
// Minimal ANSI SGR (Select Graphic Rendition) state machine. Consumes a
// stream of characters, yields (attrs, text) runs suitable for
// AttributedString rendering in LogConsoleView. See docs/ARCHITECTURE.md §11.
//
// Only SGR (ESC [ ... m) is retained. Cursor, erase, scroll, and other
// sequences are stripped so a chatty progress bar doesn't break layout.

import Foundation

public struct ANSIAttributes: Sendable, Hashable {
  public var bold: Bool = false
  public var dim: Bool = false
  public var italic: Bool = false
  public var underline: Bool = false
  public var inverse: Bool = false
  public var strikethrough: Bool = false
  public var foreground: ANSIColor? = nil
  public var background: ANSIColor? = nil

  public init() {}

  public static let plain = ANSIAttributes()
}

public enum ANSIColor: Sendable, Hashable {
  case black, red, green, yellow, blue, magenta, cyan, white
  case brightBlack, brightRed, brightGreen, brightYellow
  case brightBlue, brightMagenta, brightCyan, brightWhite
  case indexed(Int)
  case rgb(r: Int, g: Int, b: Int)
}

public struct ANSIRun: Sendable, Hashable {
  public let attrs: ANSIAttributes
  public let text: String

  public init(attrs: ANSIAttributes, text: String) {
    self.attrs = attrs
    self.text = text
  }
}

public struct ANSIParser: Sendable {
  public init() {}

  /// Parse `input` into attributed runs. Stateless across calls; use
  /// `StatefulANSIParser` to preserve attribute state across chunks.
  public func parse(_ input: String) -> [ANSIRun] {
    var parser = StatefulANSIParser()
    parser.feed(input)
    return parser.drain()
  }
}

public struct StatefulANSIParser: Sendable {
  private var current = ANSIAttributes()
  private var pendingRuns: [ANSIRun] = []
  private var textBuffer = ""
  private enum State { case text, esc, csi }
  private var state: State = .text
  private var csiParams = ""

  public init() {}

  public mutating func feed(_ input: String) {
    for ch in input {
      switch state {
      case .text:
        if ch == "\u{1B}" {
          flushText()
          state = .esc
        } else {
          textBuffer.append(ch)
        }
      case .esc:
        if ch == "[" {
          state = .csi
          csiParams = ""
        } else {
          state = .text
        }
      case .csi:
        if ch.isLetter {
          if ch == "m" {
            applySGR(csiParams)
          }
          csiParams = ""
          state = .text
        } else {
          csiParams.append(ch)
        }
      }
    }
  }

  public mutating func drain() -> [ANSIRun] {
    flushText()
    let out = pendingRuns
    pendingRuns.removeAll()
    return out
  }

  // MARK: - Private

  private mutating func flushText() {
    guard !textBuffer.isEmpty else { return }
    pendingRuns.append(ANSIRun(attrs: current, text: textBuffer))
    textBuffer = ""
  }

  private mutating func applySGR(_ params: String) {
    let codes = params.split(separator: ";").compactMap { Int($0) }
    let sequence = codes.isEmpty ? [0] : codes

    var i = 0
    while i < sequence.count {
      let c = sequence[i]
      switch c {
      case 0: current = .plain
      case 1: current.bold = true
      case 2: current.dim = true
      case 3: current.italic = true
      case 4: current.underline = true
      case 7: current.inverse = true
      case 9: current.strikethrough = true
      case 22: current.bold = false; current.dim = false
      case 23: current.italic = false
      case 24: current.underline = false
      case 27: current.inverse = false
      case 29: current.strikethrough = false
      case 30...37: current.foreground = Self.basic(c - 30)
      case 38:
        if let (color, consumed) = Self.extendedColor(from: sequence, at: i + 1) {
          current.foreground = color
          i += consumed
        }
      case 39: current.foreground = nil
      case 40...47: current.background = Self.basic(c - 40)
      case 48:
        if let (color, consumed) = Self.extendedColor(from: sequence, at: i + 1) {
          current.background = color
          i += consumed
        }
      case 49: current.background = nil
      case 90...97: current.foreground = Self.bright(c - 90)
      case 100...107: current.background = Self.bright(c - 100)
      default: break
      }
      i += 1
    }
  }

  private static func basic(_ idx: Int) -> ANSIColor {
    switch idx {
    case 0: return .black
    case 1: return .red
    case 2: return .green
    case 3: return .yellow
    case 4: return .blue
    case 5: return .magenta
    case 6: return .cyan
    case 7: return .white
    default: return .white
    }
  }

  private static func bright(_ idx: Int) -> ANSIColor {
    switch idx {
    case 0: return .brightBlack
    case 1: return .brightRed
    case 2: return .brightGreen
    case 3: return .brightYellow
    case 4: return .brightBlue
    case 5: return .brightMagenta
    case 6: return .brightCyan
    case 7: return .brightWhite
    default: return .brightWhite
    }
  }

  private static func extendedColor(
    from codes: [Int], at start: Int
  ) -> (ANSIColor, consumed: Int)? {
    guard start < codes.count else { return nil }
    switch codes[start] {
    case 5 where start + 1 < codes.count:
      return (.indexed(codes[start + 1]), 2)
    case 2 where start + 3 < codes.count:
      return (.rgb(r: codes[start + 1], g: codes[start + 2], b: codes[start + 3]), 4)
    default:
      return nil
    }
  }
}
