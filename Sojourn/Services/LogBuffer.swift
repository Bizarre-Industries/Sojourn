// Sojourn — LogBuffer
//
// Ring buffer of log lines with a broadcaster. Every Job owns one; the log
// console view subscribes to its stream. Bounded capacity prevents runaway
// memory from chatty processes (e.g., npm install). See docs/ARCHITECTURE.md
// §11 and §18 (observability).

import Foundation

public struct LogLine: Sendable, Hashable {
  public let stream: StreamTag
  public let text: String
  public let timestamp: Date

  public init(stream: StreamTag, text: String, timestamp: Date = Date()) {
    self.stream = stream
    self.text = text
    self.timestamp = timestamp
  }
}

public actor LogBuffer {
  public let id: LogBufferID
  public let capacity: Int

  private var lines: [LogLine] = []
  private var continuations: [UUID: AsyncStream<LogLine>.Continuation] = [:]
  private var finished = false
  private var partialStdout = ""
  private var partialStderr = ""

  public init(id: LogBufferID = LogBufferID(), capacity: Int = 10_000) {
    self.id = id
    self.capacity = capacity
  }

  /// Append a finished line. Drops the oldest entries in a 10% batch when
  /// capacity is reached to amortize the array shift cost.
  public func append(_ line: LogLine) {
    if lines.count >= capacity {
      lines.removeFirst(max(1, capacity / 10))
    }
    lines.append(line)
    for cont in continuations.values {
      cont.yield(line)
    }
  }

  /// Feed a raw chunk from `SubprocessRunner`. Splits on `\n` and
  /// accumulates any trailing partial line across calls.
  public func feed(_ chunk: StreamChunk) {
    guard let text = String(data: chunk.data, encoding: .utf8) else {
      append(LogLine(stream: chunk.stream, text: "[non-utf8 chunk: \(chunk.data.count)B]"))
      return
    }
    feed(text: text, stream: chunk.stream, timestamp: chunk.timestamp)
  }

  private func feed(text: String, stream: StreamTag, timestamp: Date) {
    let combined: String
    switch stream {
    case .stdout: combined = partialStdout + text
    case .stderr: combined = partialStderr + text
    }
    let parts = combined.split(
      separator: "\n", omittingEmptySubsequences: false
    )
    let complete = parts.dropLast()
    let trailing = parts.last.map(String.init) ?? ""
    switch stream {
    case .stdout: partialStdout = trailing
    case .stderr: partialStderr = trailing
    }
    for s in complete {
      append(LogLine(stream: stream, text: String(s), timestamp: timestamp))
    }
  }

  /// Flush any trailing partial-line bytes. Call when the source stream ends.
  public func flushPartials() {
    if !partialStdout.isEmpty {
      append(LogLine(stream: .stdout, text: partialStdout))
      partialStdout = ""
    }
    if !partialStderr.isEmpty {
      append(LogLine(stream: .stderr, text: partialStderr))
      partialStderr = ""
    }
  }

  /// Snapshot of all currently buffered lines.
  public func snapshot() -> [LogLine] { lines }

  /// Subscribe to live line events. Replays the current buffer first, then
  /// streams future lines. The stream finishes when `close()` is called.
  public func subscribe() -> AsyncStream<LogLine> {
    let subID = UUID()
    return AsyncStream { continuation in
      for line in lines { continuation.yield(line) }
      continuations[subID] = continuation
      continuation.onTermination = { [weak self] _ in
        Task { await self?.removeSubscriber(subID) }
      }
      if finished { continuation.finish() }
    }
  }

  /// Finalize: flush partials and close all subscribers.
  public func close() {
    flushPartials()
    finished = true
    for cont in continuations.values {
      cont.finish()
    }
    continuations.removeAll()
  }

  // MARK: - Private

  private func removeSubscriber(_ id: UUID) {
    continuations.removeValue(forKey: id)
  }
}
