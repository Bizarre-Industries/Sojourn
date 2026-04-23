// Sojourn — SubprocessError
//
// Typed errors emitted by `SubprocessRunner`. See docs/ARCHITECTURE.md §11
// and CLAUDE.md ("Errors are typed enum per service. Surface causes.").

import Foundation

public enum SubprocessError: Error, Sendable {
  /// `Process.run()` failed before the child started. Usually a missing
  /// executable, permission denied, or bad argv encoding. Contains the
  /// underlying system description.
  case spawnFailed(String)

  /// Child exited with a non-zero status. Captures both streams for
  /// diagnostics; UI layers surface them through `JobRunner`/`LogBuffer`.
  case nonZeroExit(code: Int32, stdout: Data, stderr: Data)

  /// `timeout` passed to `run(...)` elapsed; child was SIGTERM'd then
  /// SIGKILL'd after a 5s grace window.
  case timedOut(elapsed: TimeInterval)

  /// The enclosing `Task` was cancelled before the child finished.
  case cancelled
}

extension SubprocessError: Equatable {
  public static func == (lhs: SubprocessError, rhs: SubprocessError) -> Bool {
    switch (lhs, rhs) {
    case (.spawnFailed(let a), .spawnFailed(let b)): return a == b
    case (.nonZeroExit(let a, _, _), .nonZeroExit(let b, _, _)): return a == b
    case (.timedOut(let a), .timedOut(let b)): return a == b
    case (.cancelled, .cancelled): return true
    default: return false
    }
  }
}
