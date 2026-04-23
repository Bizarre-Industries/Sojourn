// Sojourn — SubprocessRunner
//
// Single chokepoint for every external-process invocation. Per
// docs/ARCHITECTURE.md §11 and LICENSING.md §1 (IPC-not-linking invariant):
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
  internal init() {}

  // MARK: - Run-to-completion

  /// Spawn `tool` with `args`, wait for exit, return captured stdout/stderr.
  /// Throws `SubprocessError` on spawn failure, non-zero exit, timeout, or
  /// task cancellation. `timeout` is optional wall-clock seconds; on expiry
  /// SIGTERM is sent, then SIGKILL after a 5s grace window.
  internal func run(
    tool: URL,
    args: [String] = [],
    env: [String: String]? = nil,
    cwd: URL? = nil,
    timeout: TimeInterval? = nil
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

    do {
      try process.run()
    } catch {
      throw SubprocessError.spawnFailed(error.localizedDescription)
    }

    // Drain pipes concurrently; availableData returns empty Data on EOF.
    let stdoutTask = Task.detached { Self.drain(stdoutPipe.fileHandleForReading) }
    let stderrTask = Task.detached { Self.drain(stderrPipe.fileHandleForReading) }

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
        if process.isRunning { process.terminate() }
      }
    } catch is CancellationError {
      if process.isRunning { process.terminate() }
      await exitBox.wait()
      throw SubprocessError.cancelled
    }

    let stdout = await stdoutTask.value
    let stderr = await stderrTask.value

    let code = process.terminationStatus

    if timedOut {
      throw SubprocessError.timedOut(elapsed: Date().timeIntervalSince(startedAt))
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
    cwd: URL? = nil
  ) -> AsyncThrowingStream<StreamChunk, any Error> {
    AsyncThrowingStream(StreamChunk.self, bufferingPolicy: .unbounded) { continuation in
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

      stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if data.isEmpty {
          handle.readabilityHandler = nil
          return
        }
        outCollector.append(data)
        continuation.yield(StreamChunk(stream: .stdout, data: data))
      }
      stderrPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if data.isEmpty {
          handle.readabilityHandler = nil
          return
        }
        errCollector.append(data)
        continuation.yield(StreamChunk(stream: .stderr, data: data))
      }

      process.terminationHandler = { proc in
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        // Drain tail bytes that landed between the last readabilityHandler
        // invocation and terminationHandler.
        if let tailOut = try? stdoutPipe.fileHandleForReading.readToEnd(),
           !tailOut.isEmpty {
          outCollector.append(tailOut)
          continuation.yield(StreamChunk(stream: .stdout, data: tailOut))
        }
        if let tailErr = try? stderrPipe.fileHandleForReading.readToEnd(),
           !tailErr.isEmpty {
          errCollector.append(tailErr)
          continuation.yield(StreamChunk(stream: .stderr, data: tailErr))
        }

        let code = proc.terminationStatus
        if code != 0 {
          continuation.finish(throwing: SubprocessError.nonZeroExit(
            code: code, stdout: outCollector.snapshot, stderr: errCollector.snapshot
          ))
        } else {
          continuation.finish()
        }
      }

      continuation.onTermination = { _ in
        if process.isRunning { process.terminate() }
      }

      do {
        try process.run()
      } catch {
        continuation.finish(throwing: SubprocessError.spawnFailed(error.localizedDescription))
      }
    }
  }

  // MARK: - Private helpers

  private static func drain(_ handle: FileHandle) -> Data {
    var acc = Data()
    while true {
      let chunk = handle.availableData
      if chunk.isEmpty { break }
      acc.append(chunk)
    }
    return acc
  }

  /// Returns true if the timeout fired (meaning we SIGTERM'd the child).
  private static func awaitExitOrTimeout(
    process: Process,
    exit: ExitBox,
    timeout: TimeInterval
  ) async throws -> Bool {
    return try await withThrowingTaskGroup(of: TimeoutOutcome.self) { group in
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
        if process.isRunning { process.terminate() }
        try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
        if process.isRunning {
          kill(process.processIdentifier, SIGKILL)
        }
        await exit.wait()
        group.cancelAll()
        return true
      }
    }
  }
}

private enum TimeoutOutcome: Sendable {
  case exited
  case timedOut
}

/// Thread-safe byte accumulator for the stream path.
private final class ChunkCollector: @unchecked Sendable {
  private var buffer = Data()
  private let lock = NSLock()

  func append(_ data: Data) {
    lock.lock(); defer { lock.unlock() }
    buffer.append(data)
  }

  var snapshot: Data {
    lock.lock(); defer { lock.unlock() }
    return buffer
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
