// Sojourn — Brewfile AST model
//
// Per ADR-0018: brew bundle is the single backend. The `Brewfile` is the
// declarative source of truth committed via chezmoi. We parse to AST, never
// compare raw strings (lessons.md "brew JSON output flaps between minor
// versions" applies to bundle output too — indentation/comment style flaps).
//
// Refs: ADR-0018; docs/process/plans/v0.2-plan.md step 5; brew bundle CLI
// surface verified empirically against Homebrew 5.1.8 on 2026-05-01.

import Foundation

/// A single Brewfile line. Comments and blank lines preserved so a
/// dump → parse → serialize round-trip yields a stable diff.
internal enum BrewfileEntry: Hashable, Sendable {
  case tap(String)
  case brew(String, options: [String: String] = [:])
  case cask(String, options: [String: String] = [:])
  case mas(String, id: Int)
  case vscode(String)
  case go(String)
  case cargo(String)
  case uv(String)
  case krew(String)
  case npm(String)
  case flatpak(String)
  case comment(String)
  case blank

  /// Tier classification for the cooldown policy (ADR-0018 § "Cooldown
  /// tiers per Brewfile line type"). Returns `nil` for blanks/comments.
  internal var tier: BrewfileTier? {
    switch self {
    case .mas:                                    return .a
    case .brew:                                   return .b   // refined to .c if tap is third-party (caller maintains tap registry)
    case .cask:                                   return .c   // refined to .d if third-party tap
    case .vscode:                                 return .d
    case .cargo, .npm, .go, .uv, .krew, .flatpak: return .e
    case .tap, .comment, .blank:                  return nil
    }
  }

  /// The package's identifier as it would appear in cooldowns.toml.
  internal var packageID: String? {
    switch self {
    case .tap(let s), .brew(let s, _), .cask(let s, _),
         .mas(let s, _), .vscode(let s), .go(let s),
         .cargo(let s), .uv(let s), .krew(let s),
         .npm(let s), .flatpak(let s):
      return s
    case .comment, .blank:
      return nil
    }
  }
}

/// Cooldown tiers per ADR-0018. Each tier maps to a default cooldown
/// duration; per-package overrides live in
/// `~/Library/Application Support/Sojourn/cooldowns.toml`.
internal enum BrewfileTier: String, Hashable, Sendable, CaseIterable {
  case a   // mas — 0 d
  case b   // homebrew/core brew — 7 d
  case c   // third-party tap brew, homebrew/cask — 14 d
  case d   // third-party cask, vscode — 21 d
  case e   // cargo / npm / go / uv / krew / flatpak — 30 d

  internal var defaultCooldownDays: Int {
    switch self {
    case .a: return 0
    case .b: return 7
    case .c: return 14
    case .d: return 21
    case .e: return 30
    }
  }
}

/// Parsed Brewfile — ordered entries preserving original line order.
internal struct BrewfileAST: Hashable, Sendable {
  internal var entries: [BrewfileEntry]

  internal init(entries: [BrewfileEntry] = []) {
    self.entries = entries
  }
}

extension BrewfileAST {
  /// Top-level summary counts by entry type. Used by Dashboard pane and
  /// snapshot tests as a stable comparison surface (raw text flaps between
  /// brew minor versions; counts don't).
  internal struct Counts: Equatable, Hashable, Sendable, Codable {
    internal var taps: Int = 0
    internal var brews: Int = 0
    internal var casks: Int = 0
    internal var mas: Int = 0
    internal var vscode: Int = 0
    internal var go: Int = 0
    internal var cargo: Int = 0
    internal var uv: Int = 0
    internal var krew: Int = 0
    internal var npm: Int = 0
    internal var flatpak: Int = 0
  }

  internal var counts: Counts {
    var c = Counts()
    for entry in entries {
      switch entry {
      case .tap:     c.taps += 1
      case .brew:    c.brews += 1
      case .cask:    c.casks += 1
      case .mas:     c.mas += 1
      case .vscode:  c.vscode += 1
      case .go:      c.go += 1
      case .cargo:   c.cargo += 1
      case .uv:      c.uv += 1
      case .krew:    c.krew += 1
      case .npm:     c.npm += 1
      case .flatpak: c.flatpak += 1
      case .comment, .blank: break
      }
    }
    return c
  }

  /// Total non-meta entries (anything that resolves to an installable
  /// package or tap source).
  internal var packageCount: Int {
    entries.lazy.compactMap { $0.packageID }.count
  }
}

/// Parser for Brewfile text. Forgiving — unknown line types become
/// `.comment` to preserve round-trip without failing on flag drift.
internal enum BrewfileParser {
  internal static func parse(_ text: String) -> BrewfileAST {
    var ast = BrewfileAST()
    for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = String(raw)
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty {
        ast.entries.append(.blank)
        continue
      }
      if trimmed.hasPrefix("#") {
        ast.entries.append(.comment(trimmed))
        continue
      }
      if let entry = parseDirective(trimmed) {
        ast.entries.append(entry)
      } else {
        ast.entries.append(.comment(trimmed))
      }
    }
    return ast
  }

  private static func parseDirective(_ trimmed: String) -> BrewfileEntry? {
    guard let firstSpace = trimmed.firstIndex(of: " ") else { return nil }
    let kind = String(trimmed[..<firstSpace])
    let rest = String(trimmed[trimmed.index(after: firstSpace)...])
        .trimmingCharacters(in: .whitespaces)
    guard let (name, options) = parseQuotedNameAndOptions(rest) else {
      return nil
    }
    switch kind {
    case "tap":     return .tap(name)
    case "brew":    return .brew(name, options: options)
    case "cask":    return .cask(name, options: options)
    case "mas":
      guard let idStr = options["id"], let id = Int(idStr) else { return nil }
      return .mas(name, id: id)
    case "vscode":  return .vscode(name)
    case "go":      return .go(name)
    case "cargo":   return .cargo(name)
    case "uv":      return .uv(name)
    case "krew":    return .krew(name)
    case "npm":     return .npm(name)
    case "flatpak": return .flatpak(name)
    default:        return nil
    }
  }

  /// Extracts `"name"` and any `key: value` pairs (id: int, args: [...], etc.)
  /// from the right-hand side of a directive. Whitespace-tolerant; handles
  /// `mas "Xcode", id: 497799835` and `brew "go@1.21", link: false`.
  private static func parseQuotedNameAndOptions(_ rest: String)
    -> (String, [String: String])?
  {
    guard rest.hasPrefix("\"") else { return nil }
    let afterOpen = rest.index(after: rest.startIndex)
    guard let closeQuote = rest[afterOpen...].firstIndex(of: "\"") else {
      return nil
    }
    let name = String(rest[afterOpen..<closeQuote])
    var options: [String: String] = [:]
    let after = rest.index(after: closeQuote)
    if after < rest.endIndex {
      let trailing = rest[after...].trimmingCharacters(in: .whitespaces)
      if trailing.hasPrefix(",") {
        let optsText = String(trailing.dropFirst()).trimmingCharacters(in: .whitespaces)
        for chunk in optsText.split(separator: ",").map({
          $0.trimmingCharacters(in: .whitespaces)
        }) {
          if let colonIdx = chunk.firstIndex(of: ":") {
            let key = String(chunk[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            var value = String(chunk[chunk.index(after: colonIdx)...])
              .trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
              value = String(value.dropFirst().dropLast())
            }
            options[key] = value
          }
        }
      }
    }
    return (name, options)
  }
}

/// Serializer for Brewfile AST → text. Stable output ordering matches input.
internal enum BrewfileSerializer {
  internal static func serialize(_ ast: BrewfileAST) -> String {
    var lines: [String] = []
    for entry in ast.entries {
      lines.append(serialize(entry))
    }
    return lines.joined(separator: "\n") + "\n"
  }

  private static func serialize(_ entry: BrewfileEntry) -> String {
    switch entry {
    case .tap(let s):
      return "tap \"\(s)\""
    case .brew(let s, let opts):
      return optionsLine(kind: "brew", name: s, options: opts)
    case .cask(let s, let opts):
      return optionsLine(kind: "cask", name: s, options: opts)
    case .mas(let s, let id):
      return "mas \"\(s)\", id: \(id)"
    case .vscode(let s):
      return "vscode \"\(s)\""
    case .go(let s):
      return "go \"\(s)\""
    case .cargo(let s):
      return "cargo \"\(s)\""
    case .uv(let s):
      return "uv \"\(s)\""
    case .krew(let s):
      return "krew \"\(s)\""
    case .npm(let s):
      return "npm \"\(s)\""
    case .flatpak(let s):
      return "flatpak \"\(s)\""
    case .comment(let s):
      return s
    case .blank:
      return ""
    }
  }

  private static func optionsLine(kind: String, name: String, options: [String: String])
    -> String
  {
    if options.isEmpty {
      return "\(kind) \"\(name)\""
    }
    let formatted = options.keys.sorted().map { key -> String in
      let value = options[key] ?? ""
      let needsQuote = !["true", "false"].contains(value) && Int(value) == nil
      return needsQuote ? "\(key): \"\(value)\"" : "\(key): \(value)"
    }.joined(separator: ", ")
    return "\(kind) \"\(name)\", \(formatted)"
  }
}
