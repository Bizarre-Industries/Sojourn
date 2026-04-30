// Sojourn — ToolInstaller actor.
//
// Audit §3.1.3. Wraps the signed-pkg install path so the bootstrap state
// machine doesn't depend directly on `BrewService` (which currently
// owns the signed-pkg `installer(8)` invocation per ADR-0008).
//
// Today: delegates to `BrewService.install(pkg:)`. Stage 14 may extend
// to drive `Authorization.framework` directly.

import Foundation

internal actor ToolInstaller {
  private let brew: BrewService

  internal init(brew: BrewService) {
    self.brew = brew
  }

  /// Install Homebrew via the signed `.pkg`. Surfaces the macOS
  /// Authorization sheet to the user; never silent.
  internal func installHomebrew() async throws {
    let release = try await brew.resolveLatestRelease()
    let dest = FileManager.default.temporaryDirectory
      .appendingPathComponent("homebrew-\(release.tagName).pkg")
    try await brew.downloadPkg(release, to: dest)
    try await brew.verifySignature(at: dest)
    try await brew.install(pkg: dest)
  }
}
