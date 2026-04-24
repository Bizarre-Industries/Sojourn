import Foundation
import Testing
@testable import Sojourn

struct GitServiceTests {
  @Test func parsesPorcelainV2Status() {
    let raw = "1 .M N... 100644 100644 100644 0000 0000 README.md\u{0}"
            + "1 A. N... 000000 100644 100644 0000 0000 NEW.txt\u{0}"
    let entries = GitService.parseStatusPorcelain(raw)
    #expect(entries.count == 2)
    #expect(entries[0].path == "README.md")
    #expect(entries[0].indexStatus == ".")
    #expect(entries[0].worktreeStatus == "M")
    #expect(entries[1].path == "NEW.txt")
    #expect(entries[1].indexStatus == "A")
  }

  @Test func cleanEntryDetectsCleanState() {
    let e = GitStatusEntry(path: "x", indexStatus: ".", worktreeStatus: ".")
    #expect(e.isClean)
  }
}

struct MPMServiceMockTests {
  @Test func mockDecodesInstalled() async throws {
    let url = Bundle.module.url(
      forResource: "mpm-installed",
      withExtension: "json",
      subdirectory: "Fixtures"
    )!
    let data = try Data(contentsOf: url)
    let mpm = MPMService.mock { _ in data }
    let snap = try await mpm.installed()
    #expect(snap["brew"] != nil)
    #expect((snap["brew"]?.packages.count ?? 0) >= 3)
    #expect((snap["cask"]?.packages.count ?? 0) >= 2)
  }

  @Test func mockSurfacesDecodeErrors() async {
    let mpm = MPMService.mock { _ in Data("{not json".utf8) }
    do {
      _ = try await mpm.installed()
      Issue.record("expected decodeFailed")
    } catch is MPMError {
      // ok
    } catch {
      Issue.record("unexpected: \(error)")
    }
  }
}

struct ChezmoiServiceTests {
  @Test func decodesManagedFixture() async throws {
    let url = Bundle.module.url(
      forResource: "chezmoi-managed",
      withExtension: "json",
      subdirectory: "Fixtures"
    )!
    let data = try Data(contentsOf: url)
    let ch = ChezmoiService.mock { _ in data }
    let entries = try await ch.managed()
    #expect(entries.count == 3)
    #expect(entries[0].name == "dot_zshrc")
    #expect(entries[2].type == "dir")
  }
}

struct PrefServiceTests {
  @Test func canAccessHandlesFailure() async {
    let pref = PrefService.mock { _, _ in
      throw SubprocessError.nonZeroExit(code: 1, stdout: Data(), stderr: Data())
    }
    let ok = await pref.canAccess(domain: "com.example.does.not.exist")
    #expect(ok == false)
  }
}

struct SecretScanServiceTests {
  @Test func decodesFixtureReport() async throws {
    let url = Bundle.module.url(
      forResource: "gitleaks-report",
      withExtension: "json",
      subdirectory: "Fixtures"
    )!
    let data = try Data(contentsOf: url)
    let scanner = SecretScanService.mock { _ in data }
    let findings = try await scanner.scanDirectory(URL(fileURLWithPath: "/tmp"))
    #expect(findings.count == 1)
    #expect(findings[0].ruleID == "github-pat")
    #expect(findings[0].isHighConfidence)
  }

  @Test func emptyReportYieldsNoFindings() async throws {
    let scanner = SecretScanService.mock { _ in Data() }
    let findings = try await scanner.scanDirectory(URL(fileURLWithPath: "/tmp"))
    #expect(findings.isEmpty)
  }

  @Test func nonHighConfidenceRuleIsFlaggedCorrectly() {
    let f = SecretFinding(
      description: "generic entropy",
      file: "x",
      startLine: 1,
      endLine: 1,
      match: "xyz",
      secret: "xyz",
      ruleID: "generic-high-entropy",
      fingerprint: "fp1",
      entropy: 4.2
    )
    #expect(!f.isHighConfidence)
  }
}

@MainActor
struct BootstrapServiceTests {
  @Test func probeReportsInventoryOrReady() async {
    let locator = ToolLocator()
    await locator.seed([
      ToolResolution(
        tool: "git",
        url: URL(fileURLWithPath: "/usr/bin/git"),
        source: .candidate
      )
    ])

    let runner = SubprocessRunner()
    let brew = BrewService(
      runCommand: { _, _, _ in
        SubprocessResult(exitCode: 0, stdout: Data(), stderr: Data())
      },
      fetch: { _ in (Data(), URLResponse()) }
    )
    let bs = BootstrapService(locator: locator, brew: brew, subprocess: runner)
    await bs.probe()
    switch bs.state {
    case .reportingStatus, .ready:
      break
    default:
      Issue.record("unexpected state: \(bs.state)")
    }
  }
}
