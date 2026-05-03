// Sojourn — ContainersService tests
//
// Parser tests against checked-in fixtures (real-shape `<tool>
// --version` output per ADR-0023). Subprocess invocation is NOT
// exercised here — fixture-driven integration suites against real
// binaries live in the dev-Mac smoke check (per v0.3-plan.md
// stage 2 exit criterion + plan §"Verification rule").
//
// Refs: docs/decisions/0023-containers-panel-detection.md;
//       SojournTests/Services/BrewBundleServiceTests.swift (pattern).

import Foundation
@testable import Sojourn
import Testing

struct ContainersVersionParserTests {
  @Test func parsesDockerFixture() throws {
    let text = try fixture("docker-version")
    let v = ContainersVersionParser.parse(stdout: text, runtime: .docker)
    #expect(v == "29.4.1")
  }

  @Test func parsesOrbStackFixture() throws {
    let text = try fixture("orb-version")
    let v = ContainersVersionParser.parse(stdout: text, runtime: .orbstack)
    #expect(v == "2.0.0")
  }

  @Test func parsesAppleContainerFixture() throws {
    let text = try fixture("container-version")
    let v = ContainersVersionParser.parse(stdout: text, runtime: .appleContainer)
    #expect(v == "0.4.0")
  }

  @Test func parsesLimactlFixture() throws {
    let text = try fixture("limactl-version")
    let v = ContainersVersionParser.parse(stdout: text, runtime: .lima)
    #expect(v == "2.1.1")
  }

  @Test func parsesColimaFixture() throws {
    let text = try fixture("colima-version")
    let v = ContainersVersionParser.parse(stdout: text, runtime: .colima)
    #expect(v == "0.7.0")
  }

  @Test func emptyInputReturnsNil() {
    #expect(ContainersVersionParser.parse(stdout: "", runtime: .docker) == nil)
    #expect(ContainersVersionParser.parse(stdout: "\n\n", runtime: .docker) == nil)
  }

  @Test func unparseableInputReturnsNil() {
    let garbage = "not a version line\nsecond line"
    #expect(ContainersVersionParser.parse(stdout: garbage, runtime: .docker) == nil)
  }

  @Test func handlesTwoComponentVersion() {
    // Some tools (rare) emit X.Y without patch.
    let text = "tool 1.2"
    let v = ContainersVersionParser.parse(stdout: text, runtime: .docker)
    #expect(v == "1.2")
  }

  @Test func handlesPrereleaseSuffix() {
    let text = "Docker version 30.0.0-rc.1, build deadbeef"
    let v = ContainersVersionParser.parse(stdout: text, runtime: .docker)
    #expect(v == "30.0.0-rc.1")
  }

  @Test func rejectsIPv4LookingTokens() {
    // Looks like 4 dots — should NOT be matched.
    let text = "server at 192.168.1.42 ready"
    #expect(ContainersVersionParser.parse(stdout: text, runtime: .docker) == nil)
  }

  // MARK: - Helpers

  private func fixture(_ name: String) throws -> String {
    let url = try #require(
      Bundle.sojournFixtureURL(name: "containers/\(name)", ext: "txt"),
      "containers/\(name).txt fixture not found"
    )
    return try String(contentsOf: url, encoding: .utf8)
  }
}

struct ContainerRuntimePriorityTests {
  @Test func allCasesInPriorityOrder() {
    // Locked priority order per ADR-0023 §"Decision":
    // Docker > OrbStack > Apple container > Lima > Colima.
    #expect(ContainerRuntime.allCases == [
      .docker, .orbstack, .appleContainer, .lima, .colima
    ])
  }

  @Test func toolNamesMatchExpected() {
    #expect(ContainerRuntime.docker.toolName == "docker")
    #expect(ContainerRuntime.orbstack.toolName == "orb")
    #expect(ContainerRuntime.appleContainer.toolName == "container")
    #expect(ContainerRuntime.lima.toolName == "limactl")
    #expect(ContainerRuntime.colima.toolName == "colima")
  }

  @Test func colimaUsesBareVersionArg() {
    // colima predates the `--version` convention; uses `version`.
    #expect(ContainerRuntime.colima.versionArgs == ["version"])
    #expect(ContainerRuntime.docker.versionArgs == ["--version"])
  }
}

struct ContainersSnapshotTests {
  @Test func emptySnapshotHasNoActiveRuntime() {
    let s = ContainersSnapshot.empty
    #expect(s.activeRuntime == nil)
    #expect(!s.anyInstalled)
  }

  @Test func activeRuntimeIsHighestPriorityInstalled() {
    // OrbStack-only installed → OrbStack is active.
    let snap = ContainersSnapshot(
      runtimes: [
        RuntimeStatus(runtime: .docker,         installed: false, version: nil,  probeError: nil),
        RuntimeStatus(runtime: .orbstack,       installed: true,  version: "2.0.0", probeError: nil),
        RuntimeStatus(runtime: .appleContainer, installed: false, version: nil,  probeError: nil),
        RuntimeStatus(runtime: .lima,           installed: true,  version: "2.1.1", probeError: nil),
        RuntimeStatus(runtime: .colima,         installed: false, version: nil,  probeError: nil)
      ],
      probedAt: Date()
    )
    #expect(snap.activeRuntime == .orbstack)
    #expect(snap.anyInstalled)
  }

  @Test func dockerWinsOverOrbStackWhenBothInstalled() {
    // ADR-0023 priority lock: Docker > OrbStack.
    let snap = ContainersSnapshot(
      runtimes: [
        RuntimeStatus(runtime: .docker,         installed: true,  version: "29.4.1", probeError: nil),
        RuntimeStatus(runtime: .orbstack,       installed: true,  version: "2.0.0",  probeError: nil),
        RuntimeStatus(runtime: .appleContainer, installed: false, version: nil,     probeError: nil),
        RuntimeStatus(runtime: .lima,           installed: false, version: nil,     probeError: nil),
        RuntimeStatus(runtime: .colima,         installed: false, version: nil,     probeError: nil)
      ],
      probedAt: Date()
    )
    #expect(snap.activeRuntime == .docker)
  }

  @Test func noRuntimesInstalledReturnsNilActive() {
    let snap = ContainersSnapshot(
      runtimes: ContainerRuntime.allCases.map {
        RuntimeStatus(runtime: $0, installed: false, version: nil, probeError: nil)
      },
      probedAt: Date()
    )
    #expect(snap.activeRuntime == nil)
    #expect(!snap.anyInstalled)
  }
}
