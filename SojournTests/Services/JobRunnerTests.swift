import Foundation
import Testing
@testable import Sojourn

@MainActor
struct JobRunnerTests {
  @Test func echoJobReachesSuccess() async throws {
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner)

    let handle = jobRunner.submit(JobRequest(
      label: "echo test",
      tool: URL(fileURLWithPath: "/bin/echo"),
      args: ["hello", "from", "job-runner"]
    ))

    try await waitForTerminal(jobRunner, jobID: handle.id)
    let job = jobRunner.job(handle.id)
    #expect(job != nil)
    guard case .succeeded(let code) = job?.state else {
      Issue.record("expected .succeeded, got \(String(describing: job?.state))")
      return
    }
    #expect(code == 0)

    let buffer = jobRunner.buffer(handle.bufferID)
    let lines = await buffer?.snapshot() ?? []
    #expect(lines.contains(where: { $0.text.contains("hello") }))
  }

  @Test func falseJobReachesFailure() async throws {
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner)

    let handle = jobRunner.submit(JobRequest(
      label: "false test",
      tool: URL(fileURLWithPath: "/usr/bin/false")
    ))

    try await waitForTerminal(jobRunner, jobID: handle.id)
    let job = jobRunner.job(handle.id)
    guard case .failed = job?.state else {
      Issue.record("expected .failed, got \(String(describing: job?.state))")
      return
    }
  }

  @Test func cancelMovesJobToTerminalState() async throws {
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner)

    let handle = jobRunner.submit(JobRequest(
      label: "sleep test",
      tool: URL(fileURLWithPath: "/bin/sleep"),
      args: ["30"]
    ))

    try await Task.sleep(nanoseconds: 100_000_000)
    jobRunner.cancel(handle.id)

    try await waitForTerminal(jobRunner, jobID: handle.id, timeoutSeconds: 10)
    let job = jobRunner.job(handle.id)
    #expect(job?.state.isTerminal == true)
  }

  @Test func purgeTerminalClearsList() async throws {
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner)

    let h = jobRunner.submit(JobRequest(
      label: "echo purge",
      tool: URL(fileURLWithPath: "/bin/echo"),
      args: ["bye"]
    ))
    try await waitForTerminal(jobRunner, jobID: h.id)
    jobRunner.purgeTerminal()
    #expect(jobRunner.jobs.isEmpty)
  }

  // MARK: - Helpers

  private func waitForTerminal(
    _ jobRunner: JobRunner,
    jobID: JobID,
    timeoutSeconds: Double = 5
  ) async throws {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
      if let job = jobRunner.job(jobID), job.state.isTerminal {
        return
      }
      try await Task.sleep(nanoseconds: 20_000_000)
    }
    Issue.record("job \(jobID) did not reach terminal state in \(timeoutSeconds)s")
  }
}
