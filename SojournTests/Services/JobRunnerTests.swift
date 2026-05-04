import Foundation
@testable import Sojourn
import Testing

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

  @Test func terminalRetentionKeepsActiveJobsAndBoundedTerminalTail() async throws {
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner, terminalRetentionLimit: 2)

    let first = jobRunner.submit(JobRequest(
      label: "echo one",
      tool: URL(fileURLWithPath: "/bin/echo"),
      args: ["one"]
    ))
    try await waitForTerminal(jobRunner, jobID: first.id)

    let active = jobRunner.submit(JobRequest(
      label: "sleep active",
      tool: URL(fileURLWithPath: "/bin/sleep"),
      args: ["2"],
      timeout: nil
    ))

    let second = jobRunner.submit(JobRequest(
      label: "echo two",
      tool: URL(fileURLWithPath: "/bin/echo"),
      args: ["two"]
    ))
    try await waitForTerminal(jobRunner, jobID: second.id)

    let third = jobRunner.submit(JobRequest(
      label: "echo three",
      tool: URL(fileURLWithPath: "/bin/echo"),
      args: ["three"]
    ))
    try await waitForTerminal(jobRunner, jobID: third.id)

    #expect(jobRunner.job(first.id) == nil)
    #expect(jobRunner.buffer(first.bufferID) == nil)
    #expect(jobRunner.job(second.id) != nil)
    #expect(jobRunner.job(third.id) != nil)
    #expect(jobRunner.job(active.id) != nil)

    jobRunner.cancel(active.id)
  }

  @Test func trackedJobCanBeCancelled() async throws {
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner)

    let task = Task {
      try await jobRunner.track(JobRequest(
        label: "tracked cancel",
        tool: URL(fileURLWithPath: "/usr/bin/env"),
        args: ["sojourn-tracked-cancel"],
        timeout: nil,
        kind: .installUpgrade
      )) {
        while true {
          try Task.checkCancellation()
          try await Task.sleep(nanoseconds: 50_000_000)
        }
      }
    }

    let jobID = try await waitForJob(jobRunner, label: "tracked cancel")
    #expect(jobRunner.canCancel(jobID))
    jobRunner.cancel(jobID)

    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    try await waitForTerminal(jobRunner, jobID: jobID)
    let job = jobRunner.job(jobID)
    #expect(job?.state == .cancelled)
    #expect(jobRunner.canCancel(jobID) == false)
  }

  @Test func trackedJobTimesOut() async throws {
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner)

    await #expect(throws: JobRunnerError.self) {
      try await jobRunner.track(JobRequest(
        label: "tracked timeout",
        tool: URL(fileURLWithPath: "/usr/bin/env"),
        args: ["sojourn-tracked-timeout"],
        timeout: 0.1,
        kind: .advisory
      )) {
        try await Task.sleep(nanoseconds: 5_000_000_000)
      }
    }

    guard let job = jobRunner.jobs.first(where: { $0.label == "tracked timeout" }) else {
      Issue.record("expected tracked timeout job")
      return
    }
    guard case .failed(let reason) = job.state else {
      Issue.record("expected .failed, got \(job.state)")
      return
    }
    #expect(reason.contains("timed out"))
    #expect(jobRunner.canCancel(job.id) == false)
  }

  // MARK: - Helpers

  private func waitForJob(
    _ jobRunner: JobRunner,
    label: String,
    timeoutSeconds: Double = 5
  ) async throws -> JobID {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
      if let job = jobRunner.jobs.first(where: { $0.label == label }) {
        return job.id
      }
      try await Task.sleep(nanoseconds: 20_000_000)
    }
    Issue.record("job \(label) was not created in \(timeoutSeconds)s")
    return JobID()
  }

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
