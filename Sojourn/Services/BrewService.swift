// Sojourn — BrewService
//
// Bootstrap installer for Homebrew. Avoids the `curl | bash` path because
// a GUI cannot cache a sudo ticket (see docs/explain/bootstrap-state-machine.md). Instead:
//
//   1. Fetch latest Homebrew release from GitHub API.
//   2. Download the signed `.pkg`.
//   3. Verify Apple signature via pkgutil --check-signature.
//   4. Hand off to /usr/sbin/installer; user gets one native Authorization
//      dialog.
//   5. Post-verify brew --version at /opt/homebrew/bin or /usr/local/bin.

import Foundation

internal enum BrewError: Error, Sendable {
  case releaseLookupFailed(String)
  case downloadFailed(String)
  case signatureVerificationFailed(String)
  case installerFailed(String)
  case postVerifyFailed
}

internal struct BrewRelease: Sendable, Hashable {
  internal let tagName: String
  internal let pkgURL: URL
}

internal actor BrewService {
  internal static let expectedInstallerTeamID = "927JGANW46"

  internal typealias Runner = @Sendable (URL, [String], URL?) async throws -> SubprocessResult
  internal typealias Fetcher = @Sendable (URL) async throws -> (Data, URLResponse)

  private let runCommand: Runner
  private let fetch: Fetcher
  internal let installerURL: URL
  internal let pkgutilURL: URL
  internal let brewCandidateURLs: [URL]

  internal init(
    installerURL: URL = URL(fileURLWithPath: "/usr/sbin/installer"),
    pkgutilURL: URL = URL(fileURLWithPath: "/usr/sbin/pkgutil"),
    brewCandidateURLs: [URL] = [
      URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
      URL(fileURLWithPath: "/usr/local/bin/brew")
    ],
    runCommand: @escaping Runner,
    fetch: @escaping Fetcher
  ) {
    self.installerURL = installerURL
    self.pkgutilURL = pkgutilURL
    self.brewCandidateURLs = brewCandidateURLs
    self.runCommand = runCommand
    self.fetch = fetch
  }

  internal static func live(runner: SubprocessRunner) -> BrewService {
    BrewService(
      runCommand: { tool, args, cwd in
        try await runner.run(tool: tool, args: args, cwd: cwd, timeout: 600)
      },
      fetch: { url in
        try await URLSession.shared.data(from: url)
      }
    )
  }

  // MARK: - Public

  internal func resolveLatestRelease() async throws -> BrewRelease {
    guard let apiURL = URL(string: "https://api.github.com/repos/Homebrew/brew/releases/latest")
    else {
      throw BrewError.releaseLookupFailed("invalid release API URL")
    }
    let (data, _) = try await fetch(apiURL)
    struct Release: Decodable {
      struct Asset: Decodable { let name: String; let browser_download_url: String }
      let tag_name: String
      let assets: [Asset]
    }
    guard let release = try? JSONDecoder().decode(Release.self, from: data) else {
      throw BrewError.releaseLookupFailed("decode failed")
    }
    guard let asset = release.assets.first(where: { $0.name.hasSuffix(".pkg") }),
      let pkgURL = URL(string: asset.browser_download_url)
    else {
      throw BrewError.releaseLookupFailed("no .pkg asset in latest release")
    }
    return BrewRelease(tagName: release.tag_name, pkgURL: pkgURL)
  }

  internal func downloadPkg(_ release: BrewRelease, to dest: URL) async throws {
    let (data, response) = try await fetch(release.pkgURL)
    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
      throw BrewError.downloadFailed("HTTP \(http.statusCode)")
    }
    try data.write(to: dest, options: .atomic)
  }

  internal func verifySignature(at pkg: URL) async throws {
    let result = try await runCommand(pkgutilURL, ["--check-signature", pkg.path], nil)
    guard Self.signatureOutputPinsHomebrewInstaller(result.stdoutString) else {
      throw BrewError.signatureVerificationFailed(result.stdoutString)
    }
  }

  internal nonisolated static func signatureOutputPinsHomebrewInstaller(_ output: String) -> Bool {
    output.contains("Developer ID Installer:")
      && output.contains("(\(expectedInstallerTeamID))")
      && output.contains("Notarization: trusted by the Apple notary service")
  }

  internal func install(pkg: URL) async throws {
    let result = try await runCommand(
      installerURL, ["-pkg", pkg.path, "-target", "/"], nil
    )
    if result.exitCode != 0 {
      throw BrewError.installerFailed(result.stderrString)
    }
  }

  internal func postVerify() async throws -> URL {
    for candidate in brewCandidateURLs
    where FileManager.default.isExecutableFile(atPath: candidate.path) {
      do {
        _ = try await runCommand(candidate, ["--version"], nil)
        return candidate
      } catch {
        continue
      }
    }
    throw BrewError.postVerifyFailed
  }
}
