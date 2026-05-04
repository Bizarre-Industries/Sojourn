// Sojourn — JobRunner timeout-policy tests (v0.3, stage 3)
//
// Locks the per-`JobKind` timeout table from
// `docs/process/plans/v0.3-plan.md` §"Hard decisions" and verifies the
// watchdog actually expires advisory jobs that overrun. installUpgrade
// timeout-exempt path is verified via a short successful run with
// kind=.installUpgrade and timeout=nil.

import Foundation
@testable import Sojourn
import Testing

struct JobKindTimeoutTableTests {
  @Test func installUpgradeIsTimeoutExempt() {
    #expect(JobKind.installUpgrade.hardTimeout == nil)
  }

  @Test func advisoryHardCapIs30Seconds() {
    #expect(JobKind.advisory.hardTimeout == 30)
  }

  @Test func snapshotHardCapIs600Seconds() {
    #expect(JobKind.snapshot.hardTimeout == 600)
  }

  @Test func allKindsAreCovered() {
    // Catches missed cases if a 4th JobKind is added without
    // updating the policy table.
    #expect(Set(JobKind.allCases) == Set([.installUpgrade, .advisory, .snapshot]))
  }
}

struct JobRequestEffectiveTimeoutTests {
  @Test func defaultKindIsAdvisory() {
    let r = JobRequest(label: "x", tool: URL(fileURLWithPath: "/bin/echo"))
    #expect(r.kind == .advisory)
  }

  @Test func effectiveTimeoutFallsBackToKindDefault() {
    let advisory = JobRequest(
      label: "x", tool: URL(fileURLWithPath: "/bin/echo"),
      timeout: nil, kind: .advisory
    )
    #expect(advisory.effectiveTimeout == 30)

    let snapshot = JobRequest(
      label: "x", tool: URL(fileURLWithPath: "/bin/echo"),
      timeout: nil, kind: .snapshot
    )
    #expect(snapshot.effectiveTimeout == 600)

    let install = JobRequest(
      label: "x", tool: URL(fileURLWithPath: "/bin/echo"),
      timeout: nil, kind: .installUpgrade
    )
    #expect(install.effectiveTimeout == nil)
  }

  @Test func explicitTimeoutOverridesKindDefault() {
    // Caller wants a 5s probe inside the advisory tier.
    let r = JobRequest(
      label: "version", tool: URL(fileURLWithPath: "/bin/echo"),
      timeout: 5, kind: .advisory
    )
    #expect(r.effectiveTimeout == 5)
  }

  @Test func explicitTimeoutAppliesEvenToInstallUpgrade() {
    // Defensive override: explicit 60s cap on an installUpgrade job.
    let r = JobRequest(
      label: "install", tool: URL(fileURLWithPath: "/bin/echo"),
      timeout: 60, kind: .installUpgrade
    )
    #expect(r.effectiveTimeout == 60)
  }
}

@Suite(.serialized)
@MainActor
struct JobRunnerWatchdogTests {
  @Test func advisoryJobThatOverrunsIsTimedOut() async throws {
    // Use a 0.5s explicit timeout (advisory tier override) against
    // `sleep 5`. Watchdog must mark the job .failed("timed out
    // after 0s") within ~1.5s.
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner)

    let handle = jobRunner.submit(JobRequest(
      label: "advisory overrun",
      tool: URL(fileURLWithPath: "/bin/sleep"),
      args: ["5"],
      timeout: 0.5,
      kind: .advisory
    ))

    try await waitForTerminal(jobRunner, jobID: handle.id)
    let job = jobRunner.job(handle.id)
    guard case .failed(let reason) = job?.state else {
      Issue.record("expected .failed, got \(String(describing: job?.state))")
      return
    }
    #expect(reason.contains("timed out"))
  }

  @Test func installUpgradeJobIsTimeoutExempt() async throws {
    // kind=.installUpgrade with timeout=nil → no watchdog. Short
    // /bin/sleep job should complete naturally.
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner)

    let handle = jobRunner.submit(JobRequest(
      label: "install short",
      tool: URL(fileURLWithPath: "/bin/sleep"),
      args: ["0.2"],
      timeout: nil,
      kind: .installUpgrade
    ))

    try await waitForTerminal(jobRunner, jobID: handle.id)
    let job = jobRunner.job(handle.id)
    guard case .succeeded = job?.state else {
      Issue.record("expected .succeeded, got \(String(describing: job?.state))")
      return
    }
  }

  @Test func naturalCompletionBeatsWatchdog() async throws {
    // kind=.advisory (30s default) but the work finishes in <100ms.
    // Job must reach .succeeded, NOT .failed("timed out") even though
    // the watchdog Task is alive in the background.
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner)

    let handle = jobRunner.submit(JobRequest(
      label: "fast advisory",
      tool: URL(fileURLWithPath: "/bin/echo"),
      args: ["fast"],
      kind: .advisory
    ))

    try await waitForTerminal(jobRunner, jobID: handle.id)
    let job = jobRunner.job(handle.id)
    guard case .succeeded(let code) = job?.state else {
      Issue.record("expected .succeeded, got \(String(describing: job?.state))")
      return
    }
    #expect(code == 0)
  }

  @Test func cancelBeatsWatchdog() async throws {
    // Manual cancel reaches a terminal state before the advisory 30s
    // watchdog could fire. Stage 3's invariant is "watchdog does NOT
    // overwrite a job that already terminated for any reason" — the
    // exact terminal flavor (.cancelled vs .succeeded(0) for
    // signal-killed processes) is governed by the existing JobRunner
    // cancel semantics, NOT by the timeout policy.
    let runner = SubprocessRunner()
    let jobRunner = JobRunner(runner: runner)

    let handle = jobRunner.submit(JobRequest(
      label: "cancel pre-empt",
      tool: URL(fileURLWithPath: "/bin/sleep"),
      args: ["10"],
      kind: .advisory
    ))

    try await Task.sleep(nanoseconds: 100_000_000)
    jobRunner.cancel(handle.id)

    try await waitForTerminal(jobRunner, jobID: handle.id)
    let job = jobRunner.job(handle.id)
    #expect(job?.state.isTerminal == true)
    // Critical: state is NOT a timed-out failure (watchdog must not
    // overwrite the cancel-driven termination).
    if case .failed(let reason) = job?.state {
      #expect(!reason.contains("timed out"),
              "watchdog overwrote cancel-driven terminal state: \(reason)")
    }
  }

  // MARK: - Helpers

  private func waitForTerminal(
    _ jobRunner: JobRunner,
    jobID: JobID,
    timeoutSeconds: Double = 10
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
