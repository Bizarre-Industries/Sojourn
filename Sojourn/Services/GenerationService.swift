// Sojourn — GenerationService
//
// Manages numbered generations: snapshot create / list / restore. Each
// generation is a `<N>.tar.zst` archive paired with a `<N>.json`
// manifest, both under `paths.generations`. Compression uses zstd
// level 19 (perf-council condition; ~4-6x ratio on text-heavy snapshots
// keeps the 30-snapshot retention under ~2 GB ceiling).
//
// Tarball contents (per v0.2-plan §6):
//   - Brewfile.common
//   - Brewfile.<hostname>
//   - prefs.toml
//   - machines.toml
//   - chezmoi-state.txt   (output of `chezmoi state dump` if chezmoi exists)
//
// Restore order:
//   1. `brew bundle install --cleanup --file=<snapshot/Brewfile.common>`
//   2. `brew bundle install --cleanup --file=<snapshot/Brewfile.<host>>`
//   3. `chezmoi apply` against the snapshot's chezmoi state
//   4. `defaults import` for plist diffs (deferred to step 9 PrefService
//      extension; Generations restores Brewfile + dotfiles in v0.2)
//
// Refs: ADR-0018; v0.2-plan.md step 6;
// .claude/council-logs/2026-05-01-v0.2-adr-batch.md (zstd-19, retention).

import Foundation

internal enum GenerationError: Error, Sendable, CustomStringConvertible {
  case generationsDirMissing(URL)
  case archiveMissing(Int)
  case manifestMissing(Int)
  case archiveCreationFailed(stderr: String)
  case archiveExtractionFailed(stderr: String)
  case manifestDecodeFailed(String)
  case noBrewfile(searched: [URL])

  internal var description: String {
    switch self {
    case .generationsDirMissing(let url):
      return "Generations directory missing: \(url.path)"
    case .archiveMissing(let n):
      return "Generation \(n) archive missing"
    case .manifestMissing(let n):
      return "Generation \(n) manifest missing"
    case .archiveCreationFailed(let stderr):
      return "tar/zstd failed: \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
    case .archiveExtractionFailed(let stderr):
      return "extract failed: \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
    case .manifestDecodeFailed(let msg):
      return "manifest decode failed: \(msg)"
    case .noBrewfile(let urls):
      return "no Brewfile found at: \(urls.map(\.path).joined(separator: ", "))"
    }
  }
}

internal actor GenerationService {
  /// Maximum retained generations per perf-council condition.
  internal static let retentionCount: Int = 30

  /// zstd compression level. -19 is "high" — favours ratio over speed,
  /// suits cold storage of historical snapshots.
  internal static let zstdLevel: Int = 19

  private let runner: SubprocessRunner
  private let paths: AppSupportPaths
  private let chezmoiSourceRoot: URL?
  private let tarURL: URL
  private let zstdURL: URL
  private let fm: FileManager

  internal init(
    runner: SubprocessRunner,
    paths: AppSupportPaths,
    chezmoiSourceRoot: URL? = nil,
    tarURL: URL = URL(fileURLWithPath: "/usr/bin/tar"),
    zstdURL: URL = URL(fileURLWithPath: "/opt/homebrew/bin/zstd"),
    fileManager: FileManager = .default
  ) {
    self.runner = runner
    self.paths = paths
    self.chezmoiSourceRoot = chezmoiSourceRoot
    self.tarURL = tarURL
    self.zstdURL = zstdURL
    self.fm = fileManager
  }

  // MARK: - List

  /// Enumerate generations on disk, newest first.
  internal func list() throws -> [GenerationManifest] {
    if !fm.fileExists(atPath: paths.generations.path) {
      throw GenerationError.generationsDirMissing(paths.generations)
    }
    let urls = try fm.contentsOfDirectory(
      at: paths.generations,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ).filter { $0.pathExtension == "json" }

    var out: [GenerationManifest] = []
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    for url in urls {
      do {
        let data = try Data(contentsOf: url)
        let manifest = try decoder.decode(GenerationManifest.self, from: data)
        out.append(manifest)
      } catch {
        throw GenerationError.manifestDecodeFailed("\(url.lastPathComponent): \(error)")
      }
    }
    return out.sorted { $0.generation.number > $1.generation.number }
  }

  // MARK: - Create

  /// Snapshot the current state into a new generation. Returns the
  /// manifest of the freshly-created snapshot.
  internal func create(
    note: String,
    brewfileCommon: URL,
    brewfileHost: URL?,
    prefsTOML: URL?,
    machinesTOML: URL?,
    chezmoiStateText: String?,
    chezmoiCommit: String? = nil,
    brewfileCounts: BrewfileAST.Counts = .init()
  ) async throws -> GenerationManifest {
    if !fm.fileExists(atPath: brewfileCommon.path) {
      throw GenerationError.noBrewfile(searched: [brewfileCommon])
    }
    let next = (try? nextGenerationNumber()) ?? 1
    let stagingDir = paths.generations
      .appendingPathComponent("staging-\(next)", isDirectory: true)
    try? fm.removeItem(at: stagingDir)
    try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: stagingDir) }

    try fm.copyItem(at: brewfileCommon,
                    to: stagingDir.appendingPathComponent("Brewfile.common"))
    if let brewfileHost, fm.fileExists(atPath: brewfileHost.path) {
      try fm.copyItem(at: brewfileHost,
                      to: stagingDir.appendingPathComponent(brewfileHost.lastPathComponent))
    }
    if let prefsTOML, fm.fileExists(atPath: prefsTOML.path) {
      try fm.copyItem(at: prefsTOML,
                      to: stagingDir.appendingPathComponent("prefs.toml"))
    }
    if let machinesTOML, fm.fileExists(atPath: machinesTOML.path) {
      try fm.copyItem(at: machinesTOML,
                      to: stagingDir.appendingPathComponent("machines.toml"))
    }
    if let chezmoiStateText {
      try chezmoiStateText.data(using: .utf8)?.write(
        to: stagingDir.appendingPathComponent("chezmoi-state.txt"))
    }

    let archive = paths.generations.appendingPathComponent("\(next).tar.zst")
    try await runTarZstd(stagingDir: stagingDir, output: archive)

    let size = (try? fm.attributesOfItem(atPath: archive.path)[.size] as? Int64) ?? 0
    let sha = try sha256Hex(of: archive)
    let manifest = GenerationManifest(
      generation: Generation(
        number: next,
        createdAt: Date(),
        chezmoiCommit: chezmoiCommit,
        note: note,
        brewfileCounts: brewfileCounts
      ),
      archiveSizeBytes: size,
      sha256: sha
    )
    try persist(manifest)
    try enforceRetention()
    return manifest
  }

  // MARK: - Restore

  /// Extract a generation's archive into a fresh staging dir under
  /// `paths.generations/restore-<N>` and return the staging URL. Caller
  /// (typically `SyncCoordinator` during a "Rollback to N" action)
  /// drives `brew bundle install` / `chezmoi apply` against it.
  internal func extract(_ number: Int) async throws -> URL {
    let archive = paths.generations.appendingPathComponent("\(number).tar.zst")
    if !fm.fileExists(atPath: archive.path) {
      throw GenerationError.archiveMissing(number)
    }
    let outDir = paths.generations
      .appendingPathComponent("restore-\(number)", isDirectory: true)
    try? fm.removeItem(at: outDir)
    try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

    // tar accepts -I "<command>" to pipe through an arbitrary
    // (de)compressor; we use zstd in decompress mode.
    let result = try await runner.run(
      tool: tarURL,
      args: [
        "-x",
        "-I", "\(zstdURL.path) -d",
        "-f", archive.path,
        "-C", outDir.path
      ],
      timeout: 600
    )
    if result.exitCode != 0 {
      throw GenerationError.archiveExtractionFailed(stderr: result.stderrString)
    }
    return outDir
  }

  // MARK: - Internals

  private func nextGenerationNumber() throws -> Int {
    let manifests = (try? list()) ?? []
    return (manifests.map(\.generation.number).max() ?? 0) + 1
  }

  private func persist(_ manifest: GenerationManifest) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(manifest)
    let url = paths.generations
      .appendingPathComponent("\(manifest.generation.number).json")
    try data.write(to: url, options: .atomic)
  }

  private func enforceRetention() throws {
    let manifests = (try? list()) ?? []
    if manifests.count <= Self.retentionCount { return }
    let stale = manifests.dropFirst(Self.retentionCount)
    for m in stale {
      let archive = paths.generations
        .appendingPathComponent("\(m.generation.number).tar.zst")
      let manifestURL = paths.generations
        .appendingPathComponent("\(m.generation.number).json")
      try? fm.removeItem(at: archive)
      try? fm.removeItem(at: manifestURL)
    }
  }

  private func runTarZstd(stagingDir: URL, output: URL) async throws {
    // tar -c -I "<zstd -19>" -C <staging> -f <output> .
    let result = try await runner.run(
      tool: tarURL,
      args: [
        "-c",
        "-I", "\(zstdURL.path) -\(Self.zstdLevel)",
        "-C", stagingDir.path,
        "-f", output.path,
        "."
      ],
      timeout: 600
    )
    if result.exitCode != 0 {
      throw GenerationError.archiveCreationFailed(stderr: result.stderrString)
    }
  }

  private func sha256Hex(of url: URL) throws -> String {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    var sha = [UInt8](repeating: 0, count: 32)
    var ctx = SHA256Context()
    ctx.absorb(data)
    ctx.finalize(into: &sha)
    return sha.map { String(format: "%02x", $0) }.joined()
  }
}

// MARK: - SHA-256 (CommonCrypto-free, Swift implementation)
//
// CommonCrypto would pull in <CommonCrypto/CommonCrypto.h> via a bridging
// header — out of scope for a pure-Swift target. This implementation is
// the stock RFC 6234 algorithm; correct, not fast (snapshot creation is
// disk-bound, hashing isn't the bottleneck).

private struct SHA256Context {
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
