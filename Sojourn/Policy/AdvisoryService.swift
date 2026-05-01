// Sojourn — AdvisoryService (v0.2)
//
// Per ADR-0021: replaces the v0.1 no-op stub with a thin shell-out
// over `brew vulns --brewfile <path> --cyclonedx`. The Homebrew tap
// `homebrew/brew-vulns` queries OSV.dev and returns OSV-format JSON.
//
// Council conditions wired in:
//   - argv-array invocation only (security)
//   - realpath validation of Brewfile against the chezmoi source root
//     or ~/.config/sojourn/ (security)
//   - OSV JSON cap: 16 MB response, depth 32 (security)
//   - Three freshness states: fresh / stale / unavailable (UX)
//   - Cache key = SHA-256 of sorted Brewfile package IDs (perf)
//   - Auto-tap of homebrew/brew-vulns is NEVER silent (architect)
//
// Refs: ADR-0021; docs/process/plans/v0.2-plan.md step 10;
// .claude/council-logs/2026-05-01-v0.2-adr-batch.md.

import Foundation

internal enum AdvisoryFreshness: String, Sendable, Hashable, Codable {
  case fresh         // cache age < 24h
  case stale         // cache age 24h–7d, last refresh failed
  case unavailable   // no cache, or cache > 7d, or tap missing
}

internal enum AdvisoryError: Error, Sendable, CustomStringConvertible {
  case brewfileRejected(String)
  case tapNotInstalled
  case nonZeroExit(code: Int32, stderr: String)
  case responseTooLarge(bytes: Int)
  case responseTooDeep
  case decodeFailed(String)

  internal var description: String {
    switch self {
    case .brewfileRejected(let path):
      return "Brewfile path rejected: \(path)"
    case .tapNotInstalled:
      return "homebrew/brew-vulns tap not installed; install with consent prompt"
    case .nonZeroExit(let code, let stderr):
      return "brew vulns exited \(code): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
    case .responseTooLarge(let bytes):
      return "brew vulns response exceeded 16 MB cap (\(bytes) bytes)"
    case .responseTooDeep:
      return "brew vulns response exceeded depth-32 cap"
    case .decodeFailed(let msg):
      return "brew vulns OSV decode failed: \(msg)"
    }
  }
}

/// In-memory snapshot served to UI. Cached on disk via the same shape.
internal struct AdvisorySnapshot: Sendable, Hashable, Codable {
  internal let advisories: [AdvisoryReference]
  internal let freshness: AdvisoryFreshness
  internal let lastSuccessAt: Date?
  internal let lastAttemptAt: Date?
  internal let cacheKeySHA256: String?
}

internal actor AdvisoryService {
  internal static let maxResponseBytes: Int = 16 * 1024 * 1024
  internal static let maxResponseDepth: Int = 32
  internal static let freshTTL: TimeInterval = 24 * 60 * 60        // 24h
  internal static let staleTTL: TimeInterval = 7 * 24 * 60 * 60    // 7d

  private let runner: SubprocessRunner
  private let brewURL: URL
  private let chezmoiSourceRoot: URL?
  private let cacheURL: URL?
  private let fm: FileManager

  private var snapshot: AdvisorySnapshot = AdvisorySnapshot(
    advisories: [],
    freshness: .unavailable,
    lastSuccessAt: nil,
    lastAttemptAt: nil,
    cacheKeySHA256: nil
  )

  internal init(
    runner: SubprocessRunner,
    brewURL: URL,
    chezmoiSourceRoot: URL? = nil,
    cacheURL: URL? = nil,
    fileManager: FileManager = .default
  ) {
    self.runner = runner
    self.brewURL = brewURL
    self.chezmoiSourceRoot = chezmoiSourceRoot
    self.cacheURL = cacheURL
    self.fm = fileManager
  }

  // MARK: - Public surface

  internal func currentSnapshot() -> AdvisorySnapshot { snapshot }

  /// Force a fresh `brew vulns` call. Caller (Advisories pane) wires
  /// this to the "Refresh" button.
  internal func refresh(brewfile: URL) async throws -> AdvisorySnapshot {
    let validated = try validateBrewfile(brewfile)
    let brewfileText = try String(contentsOf: validated, encoding: .utf8)
    let cacheKey = sha256Hex(of: cacheKeyMaterial(brewfile: brewfileText))

    do {
      try await ensureTapPresent()
      let data = try await runBrewVulns(brewfile: validated)
      try enforceCaps(data)
      let advisories = try decodeOSV(data)
      let attemptedAt = Date()
      snapshot = AdvisorySnapshot(
        advisories: advisories,
        freshness: .fresh,
        lastSuccessAt: attemptedAt,
        lastAttemptAt: attemptedAt,
        cacheKeySHA256: cacheKey
      )
      try? persistCache()
      return snapshot
    } catch {
      let now = Date()
      let fallback: AdvisoryFreshness = {
        guard let last = snapshot.lastSuccessAt else { return .unavailable }
        let age = now.timeIntervalSince(last)
        return age <= Self.staleTTL ? .stale : .unavailable
      }()
      snapshot = AdvisorySnapshot(
        advisories: snapshot.advisories,
        freshness: fallback,
        lastSuccessAt: snapshot.lastSuccessAt,
        lastAttemptAt: now,
        cacheKeySHA256: snapshot.cacheKeySHA256
      )
      try? persistCache()
      throw error
    }
  }

  /// Hydrate from disk cache. Recomputes freshness based on age.
  internal func loadFromDisk() {
    guard let cacheURL,
          let data = try? Data(contentsOf: cacheURL) else { return }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    guard let cached = try? decoder.decode(AdvisorySnapshot.self, from: data) else {
      return
    }
    let freshness = computeFreshness(lastSuccessAt: cached.lastSuccessAt)
    snapshot = AdvisorySnapshot(
      advisories: cached.advisories,
      freshness: freshness,
      lastSuccessAt: cached.lastSuccessAt,
      lastAttemptAt: cached.lastAttemptAt,
      cacheKeySHA256: cached.cacheKeySHA256
    )
  }

  // MARK: - Internals

  private func validateBrewfile(_ path: URL) throws -> URL {
    let resolved = path.resolvingSymlinksInPath().standardizedFileURL
    if !fm.fileExists(atPath: resolved.path) {
      throw AdvisoryError.brewfileRejected("not found: \(resolved.path)")
    }
    var allowed: [URL] = []
    if let cz = chezmoiSourceRoot {
      allowed.append(cz.standardizedFileURL)
    }
    let home = fm.homeDirectoryForCurrentUser
    allowed.append(home.appendingPathComponent(".config/sojourn", isDirectory: true)
      .standardizedFileURL)
    let isUnder = allowed.contains { root in
      resolved.path == root.path || resolved.path.hasPrefix(root.path + "/")
    }
    if !isUnder {
      throw AdvisoryError.brewfileRejected("outside allowed roots: \(resolved.path)")
    }
    return resolved
  }

  private func ensureTapPresent() async throws {
    let result = try await runner.run(
      tool: brewURL,
      args: ["tap-info", "--json", "homebrew/brew-vulns"],
      timeout: 30
    )
    if result.exitCode != 0 {
      throw AdvisoryError.tapNotInstalled
    }
    let stdout = result.stdoutString
    if stdout.contains("\"installed\":false")
      || stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
      throw AdvisoryError.tapNotInstalled
    }
  }

  private func runBrewVulns(brewfile: URL) async throws -> Data {
    let result = try await runner.run(
      tool: brewURL,
      args: ["vulns", "--brewfile", brewfile.path, "--cyclonedx"],
      timeout: 120
    )
    if result.exitCode != 0 {
      throw AdvisoryError.nonZeroExit(code: result.exitCode, stderr: result.stderrString)
    }
    return result.stdout
  }

  private func enforceCaps(_ data: Data) throws {
    if data.count > Self.maxResponseBytes {
      throw AdvisoryError.responseTooLarge(bytes: data.count)
    }
    var depth = 0
    var maxDepth = 0
    var inString = false
    var escape = false
    for byte in data {
      if escape { escape = false; continue }
      let scalar = UnicodeScalar(byte)
      if inString {
        if byte == 0x5C { escape = true }                  // backslash
        else if byte == 0x22 { inString = false }          // closing quote
        continue
      }
      if byte == 0x22 { inString = true; continue }
      if scalar == "{" || scalar == "[" {
        depth += 1
        if depth > maxDepth { maxDepth = depth }
        if maxDepth > Self.maxResponseDepth {
          throw AdvisoryError.responseTooDeep
        }
      } else if scalar == "}" || scalar == "]" {
        depth -= 1
      }
    }
  }

  private func decodeOSV(_ data: Data) throws -> [AdvisoryReference] {
    struct CycloneDXBOM: Decodable {
      let vulnerabilities: [CDXVuln]?
    }
    struct CDXVuln: Decodable {
      let id: String
      let description: String?
      let ratings: [CDXRating]?
      let advisories: [CDXReference]?
      let affects: [CDXAffected]?
      let published: Date?
      let updated: Date?
    }
    struct CDXRating: Decodable {
      let severity: String?
      let score: Double?
    }
    struct CDXReference: Decodable {
      let url: String
    }
    struct CDXAffected: Decodable {
      let ref: String?
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
      let bom = try decoder.decode(CycloneDXBOM.self, from: data)
      let vulns = bom.vulnerabilities ?? []
      return vulns.map { v -> AdvisoryReference in
        let severity = mapSeverity(v.ratings?.first?.severity)
        let firstURL = (v.advisories ?? []).first?.url
        let referenceURL = firstURL.flatMap { URL(string: $0) }
        let pkgs = (v.affects ?? []).compactMap { aff -> PURL? in
          guard let ref = aff.ref else { return nil }
          return PURL(
            type: "homebrew",
            namespace: nil,
            name: ref,
            version: nil,
            qualifiers: [:],
            subpath: nil
          )
        }
        return AdvisoryReference(
          id: v.id,
          feed: .osv,
          severity: severity,
          summary: v.description ?? "",
          publishedAt: v.published ?? Date(),
          modifiedAt: v.updated ?? v.published ?? Date(),
          affectedPackages: pkgs,
          fixedVersions: [],
          referenceURL: referenceURL
        )
      }
    } catch {
      throw AdvisoryError.decodeFailed("\(error)")
    }
  }

  private func mapSeverity(_ raw: String?) -> AdvisorySeverity {
    switch (raw ?? "").lowercased() {
    case "critical":      return .critical
    case "high":          return .high
    case "medium",
         "moderate":      return .moderate
    default:              return .low
    }
  }

  private func computeFreshness(lastSuccessAt: Date?) -> AdvisoryFreshness {
    guard let last = lastSuccessAt else { return .unavailable }
    let age = Date().timeIntervalSince(last)
    if age < Self.freshTTL { return .fresh }
    if age < Self.staleTTL { return .stale }
    return .unavailable
  }

  private func cacheKeyMaterial(brewfile: String) -> Data {
    let ast = BrewfileParser.parse(brewfile)
    let ids = ast.entries.compactMap { $0.packageID }.sorted()
    let joined = ids.joined(separator: "\n")
    return Data(joined.utf8)
  }

  private func sha256Hex(of data: Data) -> String {
    var sha = [UInt8](repeating: 0, count: 32)
    var ctx = AdvisorySHA256()
    ctx.absorb(data)
    ctx.finalize(into: &sha)
    return sha.map { String(format: "%02x", $0) }.joined()
  }

  private func persistCache() throws {
    guard let cacheURL else { return }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(snapshot)
    try data.write(to: cacheURL, options: .atomic)
    try? fm.setAttributes(
      [.posixPermissions: NSNumber(value: 0o600)],
      ofItemAtPath: cacheURL.path
    )
  }
}

// MARK: - Local SHA-256 (pure-Swift; mirrors GenerationService's).

private struct AdvisorySHA256 {
  private var state: [UInt32] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  ]
  private var bitCount: UInt64 = 0
  private var buffer: [UInt8] = []

  mutating func absorb(_ data: Data) {
    bitCount &+= UInt64(data.count) &* 8
    buffer.append(contentsOf: data)
    while buffer.count >= 64 {
      let block = Array(buffer.prefix(64))
      buffer.removeFirst(64)
      processBlock(block)
    }
  }

  mutating func finalize(into out: inout [UInt8]) {
    var pad: [UInt8] = [0x80]
    let remainder = (buffer.count + 1) % 64
    let padLen = remainder <= 56 ? (56 - remainder) : (120 - remainder)
    pad.append(contentsOf: [UInt8](repeating: 0, count: padLen))
    var lengthBE = bitCount.bigEndian
    withUnsafeBytes(of: &lengthBE) { pad.append(contentsOf: $0) }
    absorb(Data(pad))
    for (i, word) in state.enumerated() {
      let beWord = word.bigEndian
      withUnsafeBytes(of: beWord) { ptr in
        for (j, byte) in ptr.enumerated() {
          out[i * 4 + j] = byte
        }
      }
    }
  }

  private mutating func processBlock(_ block: [UInt8]) {
    let k: [UInt32] = [
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]
    var w = [UInt32](repeating: 0, count: 64)
    for i in 0..<16 {
      let j = i * 4
      w[i] = (UInt32(block[j]) << 24)
        | (UInt32(block[j + 1]) << 16)
        | (UInt32(block[j + 2]) << 8)
        |  UInt32(block[j + 3])
    }
    for i in 16..<64 {
      let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
      let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
      w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
    }
    var a = state[0]; var b = state[1]; var c = state[2]; var d = state[3]
    var e = state[4]; var f = state[5]; var g = state[6]; var h = state[7]
    for i in 0..<64 {
      let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
      let ch = (e & f) ^ (~e & g)
      let t1 = h &+ s1 &+ ch &+ k[i] &+ w[i]
      let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
      let mj = (a & b) ^ (a & c) ^ (b & c)
      let t2 = s0 &+ mj
      h = g; g = f; f = e; e = d &+ t1
      d = c; c = b; b = a; a = t1 &+ t2
    }
    state[0] &+= a; state[1] &+= b; state[2] &+= c; state[3] &+= d
    state[4] &+= e; state[5] &+= f; state[6] &+= g; state[7] &+= h
  }

  private func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
    (x >> n) | (x << (32 - n))
  }
}
