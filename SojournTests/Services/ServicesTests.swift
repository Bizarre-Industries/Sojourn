import Foundation
@testable import Sojourn
import Testing

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

struct ChezmoiServiceTests {
  @Test func decodesManagedFixture() async throws {
    let url = try #require(
      Bundle.sojournFixtureURL(name: "chezmoi-managed", ext: "json"),
      "chezmoi-managed.json fixture not found in test bundle"
    )
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

  @Test func loadDomainCorpusReadsBundledResource() {
    let pref = PrefService.mock { _, _ in Data() }
    let entries = pref.loadDomainCorpus()
    #expect(!entries.isEmpty)
    #expect(entries.allSatisfy { !$0.bundleID.isEmpty && !$0.displayName.isEmpty })
  }
}

struct SecretScanServiceTests {
  @Test func scanStagedRequestsStdoutJSONAndPinnedConfig() async throws {
    let config = URL(fileURLWithPath: "/tmp/sojourn-gitleaks.toml")
    let cwd = URL(fileURLWithPath: "/tmp/sojourn-data")
    let observed = ServiceEventRecorder()
    let scanner = SecretScanService(
      gitleaksURL: URL(fileURLWithPath: "/usr/local/bin/gitleaks"),
      configURL: config,
      runCommand: { args, commandCWD in
        await observed.record(args.joined(separator: "\u{1f}"))
        await observed.record(commandCWD?.path ?? "")
        return SubprocessResult(exitCode: 0, stdout: Data("[]".utf8), stderr: Data())
      }
    )

    _ = try await scanner.scanStaged(cwd: cwd)

    let events = await observed.values
    let args = events[0].split(separator: "\u{1f}").map(String.init)
    #expect(args.contains("--report-format"))
    #expect(args.contains("json"))
    #expect(args.contains("--report-path"))
    #expect(args.contains("-"))
    #expect(args.contains("--config"))
    #expect(args.contains(config.path))
    #expect(events[1] == cwd.path)
  }

  @Test func scanDirectoryUsesCurrentGitleaksDirFlags() async throws {
    let observed = ServiceEventRecorder()
    let scanner = SecretScanService(
      gitleaksURL: URL(fileURLWithPath: "/usr/local/bin/gitleaks"),
      configURL: nil,
      runCommand: { args, _ in
        await observed.record(args.joined(separator: "\u{1f}"))
        return SubprocessResult(exitCode: 0, stdout: Data("[]".utf8), stderr: Data())
      }
    )

    _ = try await scanner.scanDirectory(URL(fileURLWithPath: "/tmp/sojourn-data"))

    let args = await observed.values[0].split(separator: "\u{1f}").map(String.init)
    #expect(args.first == "dir")
    #expect(args.contains("--report-path"))
    #expect(args.contains("-"))
    #expect(!args.contains("--no-git"))
  }

  @Test func bundledConfigResolvesFromSourceTree() throws {
    let url = try #require(SecretScanService.bundledConfigURL())
    #expect(url.lastPathComponent == "gitleaks.toml")
    #expect(
      url.path.contains("Sojourn/Resources/data")
        || url.path.contains("Sojourn.app/Contents/Resources/data")
    )
  }

  @Test func bundledConfigExtendsDefaultRulesAndCapturesFullAWSKey() throws {
    let url = try #require(SecretScanService.bundledConfigURL())
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("[extend]"))
    #expect(text.contains("useDefault = true"))
    #expect(text.contains("id = \"sojourn-aws-access-key\""))
    #expect(text.contains("((?:AKIA|ASIA)[A-Z0-9]{16})"))
    #expect(text.contains("secretGroup = 1"))
  }

  @Test func decodesFixtureReport() async throws {
    let url = try #require(
      Bundle.sojournFixtureURL(name: "gitleaks-report", ext: "json"),
      "gitleaks-report.json fixture not found in test bundle"
    )
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

  @Test func oversizedReportFailsClosed() async {
    let oversized = Data(
      repeating: UInt8(ascii: " "),
      count: SecretScanService.jsonReportSizeLimit + 1
    )
    let scanner = SecretScanService.mock { _ in oversized }

    await #expect(throws: SecretScanError.self) {
      _ = try await scanner.scanDirectory(URL(fileURLWithPath: "/tmp"))
    }
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

  @Test func bundledSlackRuleBlocksAsHighConfidence() {
    let f = SecretFinding(
      description: "Slack bot token",
      file: "Brewfile.common",
      startLine: 12,
      endLine: 12,
      match: "REDACTED",
      secret: "REDACTED",
      ruleID: "sojourn-slack-bot-token",
      fingerprint: "Brewfile.common:sojourn-slack-bot-token:12",
      entropy: nil
    )
    #expect(f.isHighConfidence)
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

struct BrewServiceSignatureTests {
  @Test func verifySignatureAcceptsHomebrewInstallerTeam() async throws {
    let output = """
    Package "Homebrew.pkg":
       Status: signed by a developer certificate issued by Apple for distribution
       Notarization: trusted by the Apple notary service
       Certificate Chain:
        1. Developer ID Installer: Patrick Linnane (927JGANW46)
    """
    let brew = BrewService(
      runCommand: { _, _, _ in
        SubprocessResult(exitCode: 0, stdout: Data(output.utf8), stderr: Data())
      },
      fetch: { _ in (Data(), URLResponse()) }
    )

    try await brew.verifySignature(at: URL(fileURLWithPath: "/tmp/Homebrew.pkg"))
  }

  @Test func verifySignatureRejectsDifferentDeveloperIDInstallerTeam() async throws {
    let output = """
    Package "Homebrew.pkg":
       Status: signed by a developer certificate issued by Apple for distribution
       Notarization: trusted by the Apple notary service
       Certificate Chain:
        1. Developer ID Installer: Example Corp (ABCDE12345)
    """
    let brew = BrewService(
      runCommand: { _, _, _ in
        SubprocessResult(exitCode: 0, stdout: Data(output.utf8), stderr: Data())
      },
      fetch: { _ in (Data(), URLResponse()) }
    )

    await #expect(throws: BrewError.self) {
      try await brew.verifySignature(at: URL(fileURLWithPath: "/tmp/Homebrew.pkg"))
    }
  }
}

private actor ServiceEventRecorder {
  private var storage: [String] = []

  var values: [String] { storage }

  func record(_ value: String) {
    storage.append(value)
  }
}
