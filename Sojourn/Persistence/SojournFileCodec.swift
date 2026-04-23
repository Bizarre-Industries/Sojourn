// Sojourn — SojournFileCodec
//
// Handwritten minimal TOML decoder/encoder. Covers exactly the subset
// Sojourn emits and consumes:
//
//  - Bare keys (letters, digits, _, -).
//  - Basic strings ("..."), literal strings ('...').
//  - Booleans (true/false).
//  - Integers (decimal).
//  - Inline arrays of primitives and strings: `tags = ["a","b"]`.
//  - Tables: `[section]`.
//  - Array-of-tables: `[[packages]]`.
//  - Comments introduced by `#`.
//
// Not supported: datetimes, floats, multiline strings, nested inline
// tables, dotted keys. If a future Sojourn feature needs those, extend
// deliberately. See docs/ARCHITECTURE.md §17 (testing).

import Foundation

internal enum TOMLValue: Sendable, Hashable {
  case string(String)
  case integer(Int64)
  case boolean(Bool)
  case array([TOMLValue])
  case table([String: TOMLValue])
}

internal enum TOMLError: Error, Sendable, Equatable {
  case syntax(line: Int, reason: String)
  case typeMismatch(key: String, expected: String)
  case missingKey(String)
}

internal struct SojournFileCodec: Sendable {
  internal init() {}

  // MARK: - Decode

  internal func decode(_ input: String) throws -> [String: TOMLValue] {
    var out: [String: TOMLValue] = [:]
    var currentTablePath: [String] = []
    var arrayOfTables: [String: [[String: TOMLValue]]] = [:]
    var inArrayOfTables = false

    let lines = input.split(separator: "\n", omittingEmptySubsequences: false)
    for (idx, rawLine) in lines.enumerated() {
      let line = Self.stripComment(String(rawLine)).trimmingCharacters(in: .whitespaces)
      if line.isEmpty { continue }

      if line.hasPrefix("[[") && line.hasSuffix("]]") {
        let name = String(line.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
        currentTablePath = [name]
        inArrayOfTables = true
        arrayOfTables[name, default: []].append([:])
        continue
      }

      if line.hasPrefix("[") && line.hasSuffix("]") {
        let name = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        currentTablePath = name.split(separator: ".").map(String.init)
        inArrayOfTables = false
        continue
      }

      guard let eq = line.firstIndex(of: "=") else {
        throw TOMLError.syntax(line: idx + 1, reason: "expected '=' in '\(line)'")
      }
      let key = line[..<eq].trimmingCharacters(in: .whitespaces)
      let valueRaw = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
      let value = try Self.parseValue(valueRaw, line: idx + 1)

      if inArrayOfTables, let name = currentTablePath.first {
        if var items = arrayOfTables[name], !items.isEmpty {
          items[items.count - 1][key] = value
          arrayOfTables[name] = items
        }
      } else if currentTablePath.isEmpty {
        out[key] = value
      } else {
        Self.insert(into: &out, path: currentTablePath, key: key, value: value)
      }
    }

    for (name, items) in arrayOfTables {
      out[name] = .array(items.map { .table($0) })
    }
    return out
  }

  private static func stripComment(_ line: String) -> String {
    var inDoubleString = false
    var inSingleString = false
    for (i, ch) in line.enumerated() {
      if ch == "\"" && !inSingleString { inDoubleString.toggle() }
      if ch == "'" && !inDoubleString { inSingleString.toggle() }
      if ch == "#" && !inDoubleString && !inSingleString {
        return String(line.prefix(i))
      }
    }
    return line
  }

  private static func insert(
    into root: inout [String: TOMLValue],
    path: [String],
    key: String,
    value: TOMLValue
  ) {
    root[path[0]] = Self.merge(
      existing: root[path[0]],
      path: Array(path.dropFirst()),
      key: key,
      value: value
    )
  }

  private static func merge(
    existing: TOMLValue?,
    path: [String],
    key: String,
    value: TOMLValue
  ) -> TOMLValue {
    var table: [String: TOMLValue]
    if case .table(let t)? = existing { table = t } else { table = [:] }
    if path.isEmpty {
      table[key] = value
    } else {
      table[path[0]] = Self.merge(
        existing: table[path[0]],
        path: Array(path.dropFirst()),
        key: key,
        value: value
      )
    }
    return .table(table)
  }

  private static func parseValue(_ raw: String, line: Int) throws -> TOMLValue {
    if raw == "true" { return .boolean(true) }
    if raw == "false" { return .boolean(false) }
    if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
      return .string(Self.unescape(String(raw.dropFirst().dropLast())))
    }
    if raw.hasPrefix("'") && raw.hasSuffix("'") && raw.count >= 2 {
      return .string(String(raw.dropFirst().dropLast()))
    }
    if raw.hasPrefix("[") && raw.hasSuffix("]") {
      let inner = raw.dropFirst().dropLast()
      let parts = Self.splitArrayElements(String(inner))
      let items = try parts.map {
        try parseValue($0.trimmingCharacters(in: .whitespaces), line: line)
      }
      return .array(items)
    }
    if let intValue = Int64(raw) {
      return .integer(intValue)
    }
    throw TOMLError.syntax(line: line, reason: "unrecognized value: '\(raw)'")
  }

  private static func splitArrayElements(_ input: String) -> [String] {
    var out: [String] = []
    var depth = 0
    var buf = ""
    var inDouble = false
    var inSingle = false
    for ch in input {
      if ch == "\"" && !inSingle { inDouble.toggle() }
      if ch == "'" && !inDouble { inSingle.toggle() }
      if ch == "[" && !inDouble && !inSingle { depth += 1 }
      if ch == "]" && !inDouble && !inSingle { depth -= 1 }
      if ch == "," && depth == 0 && !inDouble && !inSingle {
        out.append(buf); buf = ""
        continue
      }
      buf.append(ch)
    }
    if !buf.trimmingCharacters(in: .whitespaces).isEmpty { out.append(buf) }
    return out
  }

  private static func unescape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\n", with: "\n")
     .replacingOccurrences(of: "\\t", with: "\t")
     .replacingOccurrences(of: "\\\"", with: "\"")
     .replacingOccurrences(of: "\\\\", with: "\\")
  }

  // MARK: - Encode

  internal func encode(_ root: [String: TOMLValue]) -> String {
    var lines: [String] = []
    let topLevel = root.filter {
      switch $0.value {
      case .table, .array: return false
      default: return true
      }
    }
    for (k, v) in topLevel.sorted(by: { $0.key < $1.key }) {
      lines.append("\(k) = \(Self.encode(v))")
    }

    for (k, v) in root.sorted(by: { $0.key < $1.key }) {
      switch v {
      case .table(let t):
        lines.append("")
        lines.append("[\(k)]")
        for (tk, tv) in t.sorted(by: { $0.key < $1.key }) {
          lines.append("\(tk) = \(Self.encode(tv))")
        }
      case .array(let items):
        let tables = items.compactMap { item -> [String: TOMLValue]? in
          if case .table(let t) = item { return t } else { return nil }
        }
        if tables.count == items.count, !tables.isEmpty {
          for t in tables {
            lines.append("")
            lines.append("[[\(k)]]")
            for (tk, tv) in t.sorted(by: { $0.key < $1.key }) {
              lines.append("\(tk) = \(Self.encode(tv))")
            }
          }
        } else if !topLevel.keys.contains(k) {
          lines.append("\(k) = \(Self.encode(v))")
        }
      default:
        break
      }
    }
    return lines.joined(separator: "\n") + "\n"
  }

  private static func encode(_ value: TOMLValue) -> String {
    switch value {
    case .string(let s):
      let escaped = s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
      return "\"\(escaped)\""
    case .integer(let i): return String(i)
    case .boolean(let b): return b ? "true" : "false"
    case .array(let a):
      return "[" + a.map(Self.encode).joined(separator: ", ") + "]"
    case .table:
      return ""
    }
  }
}

internal extension TOMLValue {
  var stringValue: String? {
    if case .string(let s) = self { return s }
    return nil
  }

  var intValue: Int64? {
    if case .integer(let i) = self { return i }
    return nil
  }

  var boolValue: Bool? {
    if case .boolean(let b) = self { return b }
    return nil
  }

  var arrayValue: [TOMLValue]? {
    if case .array(let a) = self { return a }
    return nil
  }

  var tableValue: [String: TOMLValue]? {
    if case .table(let t) = self { return t }
    return nil
  }
}
