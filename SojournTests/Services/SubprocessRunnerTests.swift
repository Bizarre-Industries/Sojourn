import Foundation
@testable import Sojourn
import Testing

/// Unit tests for SubprocessRunner. See docs/reference/architecture.md.
///
/// These tests invoke real system binaries (/bin/echo, /bin/sh, /usr/bin/true,
/// /usr/bin/false) that are guaranteed to exist on macOS. No network,
/// no brew/mpm/chezmoi — those are fixture-only per CLAUDE.md.
struct SubprocessRunnerTests {
  @Test func runEchoCollectsStdout() async throws {
    let runner = SubprocessRunner()
    let result = try await runner.run(
      tool: URL(fileURLWithPath: "/bin/echo"),
      args: ["hello", "sojourn"]
    )
    #expect(result.exitCode == 0)
    #expect(result.stdoutString == "hello sojourn\n")
    #expect(result.stderr.isEmpty)
  }

  @Test func runFalseThrowsNonZeroExit() async throws {
    let runner = SubprocessRunner()
    await #expect(throws: SubprocessError.self) {
      try await runner.run(
        tool: URL(fileURLWithPath: "/usr/bin/false"),
        args: []
      )
    }
  }

  @Test func runTrueSucceeds() async throws {
    let runner = SubprocessRunner()
    let result = try await runner.run(
      tool: URL(fileURLWithPath: "/usr/bin/true"),
      args: []
    )
    #expect(result.exitCode == 0)
  }

  @Test func runShCaptureStderr() async throws {
    let runner = SubprocessRunner()
    let result = try await runner.run(
      tool: URL(fileURLWithPath: "/bin/sh"),
      args: ["-c", "echo to-stdout; echo to-stderr >&2"]
    )
    #expect(result.stdoutString.contains("to-stdout"))
    #expect(result.stderrString.contains("to-stderr"))
  }

  @Test func runSpawnFailedForMissingBinary() async throws {
    let runner = SubprocessRunner()
    await #expect(throws: SubprocessError.self) {
      try await runner.run(
        tool: URL(fileURLWithPath: "/nonexistent/binary"),
        args: []
      )
    }
  }

  @Test func runPassesEnvironment() async throws {
    let runner = SubprocessRunner()
    let result = try await runner.run(
      tool: URL(fileURLWithPath: "/bin/sh"),
      args: ["-c", "printf '%s' \"$SOJOURN_TEST_VAR\""],
      env: ["PATH": "/usr/bin:/bin", "SOJOURN_TEST_VAR": "marker-value-42"]
    )
    #expect(result.stdoutString == "marker-value-42")
  }

  @Test func runRespectsCwd() async throws {
    let runner = SubprocessRunner()
    let result = try await runner.run(
      tool: URL(fileURLWithPath: "/bin/pwd"),
      args: [],
      cwd: URL(fileURLWithPath: "/tmp")
    )
    let out = result.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
    // /tmp is a symlink to /private/tmp on macOS; accept either.
    #expect(out == "/tmp" || out == "/private/tmp")
  }

  @Test func runHandlesLargeStdout() async throws {
    let runner = SubprocessRunner()
    // Emit ~500 KB to exercise 64 KB pipe backpressure.
    // `yes` prints "y\n" indefinitely; `head -c` caps the byte count.
    let result = try await runner.run(
      tool: URL(fileURLWithPath: "/bin/sh"),
      args: ["-c", "yes | head -c 500000"]
    )
    #expect(result.exitCode == 0)
    #expect(result.stdout.count == 500_000)
  }

  @Test func runFailsWhenCapturedOutputExceedsLimit() async throws {
    let runner = SubprocessRunner()
    do {
      _ = try await runner.run(
        tool: URL(fileURLWithPath: "/bin/sh"),
        args: ["-c", "yes | head -c 200000"],
        timeout: 5,
        outputLimitBytes: 1_024
      )
      Issue.record("expected outputTooLarge")
    } catch let error as SubprocessError {
      guard case .outputTooLarge(let stream, let limit) = error else {
        Issue.record("expected outputTooLarge, got \(error)")
        return
      }
      #expect(stream == .stdout)
      #expect(limit == 1_024)
    }
  }

  @Test func streamYieldsChunksInOrder() async throws {
    let runner = SubprocessRunner()
    let stream = runner.stream(
      tool: URL(fileURLWithPath: "/bin/sh"),
      args: ["-c", "echo line1; echo line2; echo err >&2"]
    )

    var stdoutBytes = Data()
    var stderrBytes = Data()
    for try await chunk in stream {
      switch chunk.stream {
      case .stdout: stdoutBytes.append(chunk.data)
      case .stderr: stderrBytes.append(chunk.data)
      }
    }

    let stdoutStr = String(decoding: stdoutBytes, as: UTF8.self)
    let stderrStr = String(decoding: stderrBytes, as: UTF8.self)
    #expect(stdoutStr.contains("line1"))
    #expect(stdoutStr.contains("line2"))
    #expect(stderrStr.contains("err"))
  }

  @Test func streamThrowsOnNonZeroExit() async throws {
    let runner = SubprocessRunner()
    let stream = runner.stream(
      tool: URL(fileURLWithPath: "/bin/sh"),
      args: ["-c", "echo partial; exit 7"]
    )

    var gotErr: (any Error)?
    do {
      for try await _ in stream {}
    } catch {
      gotErr = error
    }
    #expect(gotErr is SubprocessError)
    if case .nonZeroExit(let code, _, _)? = gotErr as? SubprocessError {
      #expect(code == 7)
    } else {
      Issue.record("expected .nonZeroExit(7, _, _), got \(String(describing: gotErr))")
    }
  }

  @Test func streamCapsNonZeroExitOutputSnapshots() async throws {
    let runner = SubprocessRunner()
    let stream = runner.stream(
      tool: URL(fileURLWithPath: "/bin/sh"),
      args: ["-c", "dd if=/dev/zero bs=1048576 count=2 2>/dev/null; exit 7"]
    )

    var streamedStdoutBytes = 0
    do {
      for try await chunk in stream {
        if chunk.stream == .stdout {
          streamedStdoutBytes += chunk.data.count
        }
      }
      Issue.record("expected non-zero stream failure")
    } catch let error as SubprocessError {
      guard case .nonZeroExit(let code, let stdout, _) = error else {
        Issue.record("expected .nonZeroExit, got \(error)")
        return
      }
      #expect(code == 7)
      #expect(streamedStdoutBytes >= SubprocessRunner.streamOutputSnapshotLimit)
      #expect(stdout.count == SubprocessRunner.streamOutputSnapshotLimit)
    }
  }

  @Test func streamEmitsTruncationMarkerWhenBufferDropsChunks() async throws {
    let runner = SubprocessRunner()
    let stream = runner.stream(
      tool: URL(fileURLWithPath: "/bin/sh"),
      args: ["-c", "for i in 1 2 3 4 5; do printf 'line-%s\\n' \"$i\"; sleep 0.02; done"],
      bufferLimit: 1
    )

    try await Task.sleep(nanoseconds: 200_000_000)

    var stdoutBytes = Data()
    for try await chunk in stream where chunk.stream == .stdout {
      stdoutBytes.append(chunk.data)
    }

    let stdout = String(decoding: stdoutBytes, as: UTF8.self)
    #expect(stdout.contains("[sojourn] stream output truncated before log buffer"))
  }

  @Test func timeoutCausesTimedOutError() async throws {
    let runner = SubprocessRunner()
    let start = Date()
    await #expect(throws: SubprocessError.self) {
      try await runner.run(
        tool: URL(fileURLWithPath: "/bin/sleep"),
        args: ["30"],
        timeout: 0.5
      )
    }
    let elapsed = Date().timeIntervalSince(start)
    // 0.5s timeout + up to 5s SIGKILL fallback; far less than 30s.
    #expect(elapsed < 10.0)
  }

  @Test(.timeLimit(.minutes(1))) func cancellationEscalatesSigtermResistantProcess() async throws {
    let runner = SubprocessRunner()
    let task = Task {
      try await runner.run(
        tool: URL(fileURLWithPath: "/bin/sh"),
        args: ["-c", "trap '' TERM; while true; do sleep 1; done"],
        timeout: nil
      )
    }

    try await Task.sleep(nanoseconds: 200_000_000)
    let start = Date()
    task.cancel()

    await #expect(throws: SubprocessError.self) {
      _ = try await task.value
    }
    #expect(Date().timeIntervalSince(start) < 8.0)
  }
}
