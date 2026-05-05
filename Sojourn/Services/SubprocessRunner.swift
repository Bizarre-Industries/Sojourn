// Sojourn — SubprocessRunner
//
// Single chokepoint for every external-process invocation. Per
// docs/reference/architecture.md and docs/reference/licensing.md (IPC-not-linking invariant):
// UI and services never touch `Process` directly — they go through this
// actor. Implementation uses Apple's Foundation `Process` + `Pipe` to stay
// within documented APIs (per CLAUDE.md "prefer boring, documented Apple
// APIs"). `swift-subprocess` is declared in Package.swift for future use but
// not required here.

import Foundation

internal struct SubprocessResult: Sendable {
  internal let exitCode: Int32
  internal let stdout: Data
  internal let stderr: Data

  internal var stdoutString: String { String(decoding: stdout, as: UTF8.self) }
  internal var stderrString: String { String(decoding: stderr, as: UTF8.self) }
}

internal enum StreamTag: String, Sendable, Equatable, Codable {
  case stdout
  case stderr
}

internal struct StreamChunk: Sendable {
  internal let stream: StreamTag
  internal let data: Data
  internal let timestamp: Date

  internal init(stream: StreamTag, data: Data, timestamp: Date = Date()) {
    self.stream = stream
    self.data = data
    self.timestamp = timestamp
  }
}

internal actor SubprocessRunner {
  internal static let streamOutputSnapshotLimit = 1_048_576
  internal static let streamBufferLimit = 1_024
  internal static let terminationGraceSeconds: UInt64 = 5

  internal init() {}

  // MARK: - Run-to-completion

  /// Spawn `tool` with `args`, wait for exit, return captured stdout/stderr.
  /// Throws `SubprocessError` on spawn failure, non-zero exit, timeout, or
  /// task cancellation. `timeout` is optional wall-clock seconds; on expiry
  /// SIGTERM is sent, then SIGKILL after a 5s grace window.
  /// `outputLimitBytes` bounds each captured stream for commands whose output
  /// is expected to be machine-readable and finite.
  internal func run(
    tool: URL,
    args: [String] = [],
    env: [String: String]? = nil,
    cwd: URL? = nil,
    timeout: TimeInterval? = nil,
    outputLimitBytes: Int? = nil
  ) async throws -> SubprocessResult {
    let process = Process()
    process.executableURL = tool
    process.arguments = args
    if let env { process.environment = env }
    if let cwd { process.currentDirectoryURL = cwd }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    // Pre-wire the exit continuation BEFORE launch so we don't race
    // SIGCHLD against handler installation.
    let exitBox = ExitBox()
    process.terminationHandler = { _ in exitBox.fire() }

    SojournLog.subprocess.debug(
      "run start tool=\(tool.lastPathComponent, privacy: .public) argc=\(args.count)"
    )
    do {
      try process.run()
    } catch {
      SojournLog.subprocess.error(
        "spawn failed: \(error.localizedDescription, privacy: .public)"
      )
      throw SubprocessError.spawnFailed(error.localizedDescription)
    }

    // Drain pipes concurrently; availableData returns empty Data on EOF.
    let pid = process.processIdentifier
    let stdoutTask = Task.detached {
      Self.drain(stdoutPipe.fileHandleForReading, stream: .stdout, limitBytes: outputLimitBytes, pid: pid)
    }
    let stderrTask = Task.detached {
      Self.drain(stderrPipe.fileHandleForReading, stream: .stderr, limitBytes: outputLimitBytes, pid: pid)
    }

    let startedAt = Date()
    var timedOut = false
    do {
      try await withTaskCancellationHandler {
        if let timeout {
          timedOut = try await Self.awaitExitOrTimeout(
            process: process, exit: exitBox, timeout: timeout
          )
        } else {
          await exitBox.wait()
        }
      } onCancel: {
        Self.terminateWithEscalation(process)
      }
    } catch is CancellationError {
      Self.terminateWithEscalation(process)
      await exitBox.wait()
      throw SubprocessError.cancelled
    }

    let stdoutDrain = await stdoutTask.value
    let stderrDrain = await stderrTask.value
    let stdout = stdoutDrain.data
    let stderr = stderrDrain.data

    let code = process.terminationStatus

    if timedOut {
      throw SubprocessError.timedOut(elapsed: Date().timeIntervalSince(startedAt))
    }

    if stdoutDrain.limitExceeded {
      throw SubprocessError.outputTooLarge(stream: .stdout, limit: outputLimitBytes ?? 0)
    }
    if stderrDrain.limitExceeded {
      throw SubprocessError.outputTooLarge(stream: .stderr, limit: outputLimitBytes ?? 0)
    }

    if Task.isCancelled {
      throw SubprocessError.cancelled
    }

    if code != 0 {
      throw SubprocessError.nonZeroExit(code: code, stdout: stdout, stderr: stderr)
    }

    return SubprocessResult(exitCode: code, stdout: stdout, stderr: stderr)
  }

  // MARK: - Streaming

  /// Spawn `tool` and yield chunks as they arrive on stdout/stderr. The
  /// stream finishes when the child exits with status 0; it throws
  /// `SubprocessError.nonZeroExit` otherwise. Call-site can cancel via the
  /// stream's task; that SIGTERM's the child.
  internal nonisolated func stream(
    tool: URL,
    args: [String] = [],
    env: [String: String]? = nil,
    cwd: URL? = nil,
    bufferLimit: Int = SubprocessRunner.streamBufferLimit
  ) -> AsyncThrowingStream<StreamChunk, any Error> {
    AsyncThrowingStream(
      StreamChunk.self,
      bufferingPolicy: .bufferingNewest(bufferLimit)
    ) { continuation in
      let process = Process()
      process.executableURL = tool
      process.arguments = args
      if let env { process.environment = env }
      if let cwd { process.currentDirectoryURL = cwd }

      let stdoutPipe = Pipe()
      let stderrPipe = Pipe()
      process.standardOutput = stdoutPipe
      process.standardError = stderrPipe

      let outCollector = ChunkCollector()
      let errCollector = ChunkCollector()

      let stdoutTask = Task.detached {
        Self.drainStream(
          stdoutPipe.fileHandleForReading,
          stream: .stdout,
          collector: outCollector,
          continuation: continuation
        )
      }
      let stderrTask = Task.detached {
        Self.drainStream(
          stderrPipe.fileHandleForReading,
          stream: .stderr,
          collector: errCollector,
          continuation: continuation
        )
      }

      process.terminationHandler = { proc in
        Task {
          _ = await stdoutTask.value
          _ = await stderrTask.value
          Self.emitDropMarkerIfNeeded(
            stream: .stdout,
            collector: outCollector,
            continuation: continuation
          )
          Self.emitDropMarkerIfNeeded(
            stream: .stderr,
            collector: errCollector,
            continuation: continuation
          )
          let code = proc.terminationStatus
          if code != 0 {
            continuation.finish(throwing: SubprocessError.nonZeroExit(
              code: code, stdout: outCollector.snapshot, stderr: errCollector.snapshot
            ))
          } else {
            continuation.finish()
          }
        }
      }

      continuation.onTermination = { _ in
        Self.terminateWithEscalation(process)
        stdoutTask.cancel()
        stderrTask.cancel()
      }

      do {
        try process.run()
      } catch {
        stdoutTask.cancel()
        stderrTask.cancel()
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()
        continuation.finish(throwing: SubprocessError.spawnFailed(error.localizedDescription))
      }
    }
  }

  // MARK: - Private helpers

  private nonisolated static func drain(
    _ handle: FileHandle,
    stream: StreamTag,
    limitBytes: Int?,
    pid: pid_t
  ) -> DrainResult {
    var acc = Data()
    let limit = limitBytes.map { max(0, $0) }
    while true {
      let chunk = handle.availableData
      if chunk.isEmpty { break }
      if let limit, acc.count + chunk.count > limit {
        let remaining = max(0, limit - acc.count)
        if remaining > 0 {
          acc.append(chunk.prefix(remaining))
        }
        try? handle.close()
        terminatePID(pid)
        return DrainResult(stream: stream, data: acc, limitExceeded: true)
      }
      acc.append(chunk)
    }
    return DrainResult(stream: stream, data: acc, limitExceeded: false)
  }

  private nonisolated static func drainStream(
    _ handle: FileHandle,
    stream: StreamTag,
    collector: ChunkCollector,
    continuation: AsyncThrowingStream<StreamChunk, any Error>.Continuation
  ) {
    while !Task.isCancelled {
      let data = handle.availableData
      if data.isEmpty { break }
      collector.append(data)
      switch continuation.yield(StreamChunk(stream: stream, data: data)) {
      case .dropped:
        collector.recordDroppedChunk()
      case .enqueued, .terminated:
        break
      @unknown default:
        break
      }
    }
  }

  private nonisolated static func emitDropMarkerIfNeeded(
    stream: StreamTag,
    collector: ChunkCollector,
    continuation: AsyncThrowingStream<StreamChunk, any Error>.Continuation
  ) {
    let dropped = collector.droppedChunks
    guard dropped > 0 else { return }
    let marker = "\n[sojourn] stream output truncated before log buffer; \(dropped) chunk(s) dropped\n"
    _ = continuation.yield(StreamChunk(stream: stream, data: Data(marker.utf8)))
  }

  /// Returns true if the timeout fired (meaning we SIGTERM'd the child).
  private static func awaitExitOrTimeout(
    process: Process,
    exit: ExitBox,
    timeout: TimeInterval
  ) async throws -> Bool {
    try await withThrowingTaskGroup(of: TimeoutOutcome.self) { group in
      group.addTask {
        await exit.wait()
        return .exited
      }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        return .timedOut
      }
      let outcome = try await group.next() ?? .exited
      switch outcome {
      case .exited:
        group.cancelAll()
        return false
      case .timedOut:
        await terminateAndWait(process: process, exit: exit)
        group.cancelAll()
        return true
      }
    }
  }

  private nonisolated static func terminateWithEscalation(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate()
    let pid = process.processIdentifier
    DispatchQueue.global(qos: .utility).asyncAfter(
      deadline: .now() + .seconds(Int(terminationGraceSeconds))
    ) {
      guard process.isRunning else { return }
      kill(pid, SIGKILL)
    }
  }

  private nonisolated static func terminatePID(_ pid: pid_t) {
    kill(pid, SIGTERM)
  }

  private static func terminateAndWait(process: Process, exit: ExitBox) async {
    guard process.isRunning else {
      await exit.wait()
      return
    }
    process.terminate()
    try? await Task.sleep(nanoseconds: terminationGraceSeconds * 1_000_000_000)
    if process.isRunning {
      kill(process.processIdentifier, SIGKILL)
    }
    await exit.wait()
  }
}

private enum TimeoutOutcome: Sendable {
  case exited
  case timedOut
}

private struct DrainResult: Sendable {
  let stream: StreamTag
  let data: Data
  let limitExceeded: Bool
}

/// Thread-safe byte accumulator for the stream path.
private final class ChunkCollector: @unchecked Sendable {
  private var buffer = Data()
  private var dropped = 0
  private let lock = NSLock()
  private let limit: Int

  init(limit: Int = SubprocessRunner.streamOutputSnapshotLimit) {
    self.limit = max(0, limit)
  }

  func append(_ data: Data) {
    lock.lock(); defer { lock.unlock() }
    guard buffer.count < limit else { return }
    let remaining = limit - buffer.count
    buffer.append(data.prefix(remaining))
  }

  func recordDroppedChunk() {
    lock.lock(); defer { lock.unlock() }
    dropped += 1
  }

  var snapshot: Data {
    lock.lock(); defer { lock.unlock() }
    return buffer
  }

  var droppedChunks: Int {
    lock.lock(); defer { lock.unlock() }
    return dropped
  }
}

/// Latching one-shot exit continuation. `terminationHandler` may fire before
/// `wait()` is awaited; the latch captures that and replays on demand.
private final class ExitBox: @unchecked Sendable {
  private let lock = NSLock()
  private var fired = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func fire() {
    lock.lock()
    let snapshot = waiters
    waiters.removeAll()
    fired = true
    lock.unlock()
    for c in snapshot { c.resume() }
  }

  func wait() async {
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
      lock.lock()
      if fired {
        lock.unlock()
        cont.resume()
      } else {
        waiters.append(cont)
        lock.unlock()
      }
    }
  }
}
