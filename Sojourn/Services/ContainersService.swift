// Sojourn — ContainersService
//
// Read-only detection of container runtimes (Docker Desktop, OrbStack,
// Apple `container`, Lima, Colima) per ADR-0023. Probes in fixed
// priority order; surfaces installed status + parsed version per
// runtime. Active-runtime is the highest-priority installed runtime
// (filesystem-presence basis; v0.3 does not socket-probe daemon
// liveness — see ADR-0023 Alternatives).
//
// Perf invariants (council 2026-05-03 amendments to ADR-0023):
// - Filesystem-presence short-circuits the version probe via
//   ToolLocator.candidateDirectories. Binary not found → "not
//   installed" without spawning subprocess.
// - Five version probes run with `async let` parallelism inside the
//   actor (not sequential await).
// - Result is memoized for the actor's lifetime. Refresh only on
//   explicit `rescan()` (user gesture) or BootstrapCoordinator
//   tool-locator invalidation.
// - Each version-probe subprocess gets a 5s timeout (advisory tier
//   per JobRunner timeout policy in v0.3-plan.md "Hard decisions").
//
// Refs: docs/decisions/0023-containers-panel-detection.md;
//       docs/process/plans/v0.3-plan.md stage 2;
//       .claude/council-logs/2026-05-03-v0.3-adr-batch.md.

import Foundation

/// Five known container runtimes in fixed priority order.
internal enum ContainerRuntime: String, Sendable, CaseIterable, Identifiable, Hashable {
  case docker
  case orbstack
  case appleContainer
  case lima
  case colima

  internal var id: String { rawValue }

  /// Display name shown to the user.
  internal var displayName: String {
    switch self {
    case .docker:          return "Docker Desktop"
    case .orbstack:        return "OrbStack"
    case .appleContainer:  return "Apple container"
    case .lima:            return "Lima"
    case .colima:          return "Colima"
    }
  }

  /// CLI tool name probed via ToolLocator.
  internal var toolName: String {
    switch self {
    case .docker:          return "docker"
    case .orbstack:        return "orb"
    case .appleContainer:  return "container"
    case .lima:            return "limactl"
    case .colima:          return "colima"
    }
  }

  /// Argv passed to the CLI to extract the version string.
  /// Note: colima uses `version` (no `--`); the others use `--version`.
  internal var versionArgs: [String] {
    switch self {
    case .colima: return ["version"]
    default:      return ["--version"]
    }
  }
}

/// Result of probing one runtime.
internal struct RuntimeStatus: Sendable, Equatable, Identifiable {
  internal let runtime: ContainerRuntime
  internal let installed: Bool
  /// Parsed version string (e.g. "29.4.1"). Nil if not installed or
  /// version probe failed.
  internal let version: String?
  /// Probe-failure detail when `installed` is true but `version` is nil
  /// (timeout, non-zero exit, unparseable output). Surfaces in UI as
  /// "version unknown" with diagnostic hint.
  internal let probeError: String?

  internal var id: String { runtime.rawValue }
}

/// Snapshot returned by `probe()`. `runtimes` preserves
/// `ContainerRuntime.allCases` priority order. `activeRuntime` is the
/// highest-priority installed runtime, or nil if none installed.
internal struct ContainersSnapshot: Sendable, Equatable {
  internal let runtimes: [RuntimeStatus]
  internal let probedAt: Date

  internal var activeRuntime: ContainerRuntime? {
    runtimes.first { $0.installed }?.runtime
  }

  internal var anyInstalled: Bool {
    runtimes.contains { $0.installed }
  }

  internal static let empty = ContainersSnapshot(runtimes: [], probedAt: .distantPast)
}

/// Stateless parser for `<tool> --version` (or `colima version`)
/// output. Each runtime emits a recognizable single-line shape.
internal enum ContainersVersionParser {
  /// Extract the semver-ish portion from one runtime's version output.
  /// Returns nil if no version-shaped substring is present in the
  /// first non-empty line. Behavior is intentionally lenient — version
  /// strings drift across releases; rejecting unknown shapes hides
  /// useful info from users.
  internal static func parse(stdout: String, runtime: ContainerRuntime) -> String? {
    let firstLine = stdout
      .split(separator: "\n", omittingEmptySubsequences: true)
      .first
      .map(String.init)?
      .trimmingCharacters(in: .whitespaces)
    guard let firstLine, !firstLine.isEmpty else { return nil }

    // Real-shape examples (verified for docker/limactl on dev Mac
    // 2026-05-03; orb/container/colima from upstream docs):
    //
    //   docker:    "Docker version 29.4.1, build 055a478"
    //   orb:       "OrbStack 2.0.0 (commit ..., daemon ...)"
    //   container: "container 0.4.0"
    //   limactl:   "limactl version 2.1.1"
    //   colima:    "colima version 0.7.0"
    //
    // Strategy: find the first whitespace-delimited token that looks
    // like X.Y(.Z)?(-suffix)?. Strips trailing punctuation.
    let tokens = firstLine.split(whereSeparator: { $0 == " " || $0 == "," })
    for token in tokens {
      let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ",;()"))
      if isVersionShaped(cleaned) {
        return cleaned
      }
    }
    return nil
  }

  /// Match X.Y or X.Y.Z optionally followed by `-`<suffix>. Avoids
  /// matching dates or 4-octet IPs.
  private static func isVersionShaped(_ s: String) -> Bool {
    guard !s.isEmpty, s.first?.isNumber == true else { return false }
    var dotCount = 0
    for ch in s {
      if ch.isNumber { continue }
      if ch == "." { dotCount += 1; continue }
      if ch == "-" || ch.isLetter || ch == "+" { return dotCount >= 1 }
      return false
    }
    return dotCount == 1 || dotCount == 2
  }
}

/// Read-only container-runtime detection actor.
internal actor ContainersService {
  private let runner: SubprocessRunner
  private let locator: ToolLocator
  private var cache: ContainersSnapshot?

  internal init(runner: SubprocessRunner, locator: ToolLocator) {
    self.runner = runner
    self.locator = locator
  }

  /// Returns the cached snapshot if present, otherwise probes.
  internal func snapshot() async -> ContainersSnapshot {
    if let cache { return cache }
    return await rescan()
  }

  /// Forces a fresh probe of all five runtimes in parallel. Replaces
  /// the cache with the result. Called on user gesture ("Rescan"
  /// button in ContainersPane) or by BootstrapCoordinator after
  /// tool-locator invalidation.
  @discardableResult
  internal func rescan() async -> ContainersSnapshot {
    async let docker = probeOne(.docker)
    async let orb    = probeOne(.orbstack)
    async let appleC = probeOne(.appleContainer)
    async let lima   = probeOne(.lima)
    async let colima = probeOne(.colima)
    let results = await [docker, orb, appleC, lima, colima]
    let snap = ContainersSnapshot(runtimes: results, probedAt: Date())
    cache = snap
    return snap
  }

  /// Drop the cached snapshot. Next `snapshot()` call will re-probe.
  /// Called by BootstrapCoordinator when the tool-locator cache is
  /// invalidated (e.g., after a brew install added a new container
  /// runtime CLI).
  internal func invalidate() {
    cache = nil
  }

  // MARK: - Single probe

  private func probeOne(_ runtime: ContainerRuntime) async -> RuntimeStatus {
    // Filesystem short-circuit — avoids ~50-80 ms subprocess spawn.
    guard let resolution = await locator.locate(runtime.toolName) else {
      return RuntimeStatus(
        runtime: runtime,
        installed: false,
        version: nil,
        probeError: nil
      )
    }
    do {
      let result = try await runner.run(
        tool: resolution.url,
        args: runtime.versionArgs,
        timeout: 5.0  // advisory tier per JobRunner policy
      )
      let stdout = result.stdoutString
      // Some tools print version to stdout; older docker variants and
      // a few CLIs go stderr. If stdout is empty, fall back to stderr.
      let source = stdout.isEmpty ? result.stderrString : stdout
      if let v = ContainersVersionParser.parse(stdout: source, runtime: runtime) {
        return RuntimeStatus(
          runtime: runtime,
          installed: true,
          version: v,
          probeError: nil
        )
      }
      // Installed but version unparseable. UI shows "version unknown".
      let preview = source.prefix(80).trimmingCharacters(in: .whitespacesAndNewlines)
      return RuntimeStatus(
        runtime: runtime,
        installed: true,
        version: nil,
        probeError: "unparseable: \(preview)"
      )
    } catch let err as SubprocessError {
      return RuntimeStatus(
        runtime: runtime,
        installed: true,
        version: nil,
        probeError: subprocessErrorDescription(err)
      )
    } catch {
      return RuntimeStatus(
        runtime: runtime,
        installed: true,
        version: nil,
        probeError: error.localizedDescription
      )
    }
  }

  private nonisolated func subprocessErrorDescription(_ err: SubprocessError) -> String {
    switch err {
    case .spawnFailed(let msg):        return "spawn failed: \(msg)"
    case .timedOut(let elapsed):       return "version probe timed out after \(Int(elapsed))s"
    case .outputTooLarge(let stream, let limit): return "\(stream.rawValue) exceeded \(limit) bytes"
    case .nonZeroExit(let code, _, _): return "exited \(code)"
    case .cancelled:                   return "cancelled"
    }
  }
}
