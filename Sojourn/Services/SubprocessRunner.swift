import Foundation

/// Wraps swift-subprocess and raw Process + Pipe + AsyncStream.
/// See docs/ARCHITECTURE.md section 11 (Subprocess execution).
actor SubprocessRunner {
  init() {}
}

/// One chunk of subprocess output.
struct OutputChunk: Sendable {
  enum Stream: Sendable { case stdout, stderr }
  let stream: Stream
  let data: Data
  let receivedAt: Date
}

/// Typed result of a completed subprocess.
struct ProcessResult: Sendable {
  let exitCode: Int32
  let stdout: Data
  let stderr: Data
}
