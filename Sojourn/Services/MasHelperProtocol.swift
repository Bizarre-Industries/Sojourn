// Sojourn — MasHelperProtocol
//
// Shared XPC contract between Sojourn (client) and MasHelper
// (privileged daemon) per ADR-0024 + council 2026-05-03 amendments.
// `@objc` so NSXPCConnection's runtime introspection works. Both
// targets compile this file; the protocol shape MUST stay byte-stable
// across MasHelper versions or older app builds will fail to talk to
// newer helpers (and vice versa).
//
// Argv discipline (council security condition): App Store IDs cross
// XPC as `NSNumber` wrapping `UInt64`. The helper validates
// `appStoreID.uint64Value > 0` on every call and invokes
// `/opt/homebrew/bin/mas` with the integer formatted via
// `String(_:radix:10)` — argv array, never a shell-interpreted string.
//
// Refs: docs/decisions/0024-mas-touch-id-privileged-helper.md;
//       .claude/council-logs/2026-05-03-v0.3-adr-batch.md.

import Foundation

/// XPC machine service name. Helper's launchd plist registers this;
/// client connects to it. Must match the helper's `MachServices`
/// dictionary key exactly.
internal let masHelperMachServiceName = "industries.bizarre.Sojourn.helper.mach"

/// Helper bundle identifier. Used by SMAppService.daemon(plistName:)
/// and by the `SMAuthorizedClients` requirement string template.
internal let masHelperBundleIdentifier = "industries.bizarre.Sojourn.helper"

/// Main app bundle identifier allowed to install and call the helper.
internal let masHelperAuthorizedClientIdentifier = "app.bizarre.sojourn"

/// Info.plist key carrying `$(DEVELOPMENT_TEAM)` after Xcode build
/// setting expansion. Release helper/client trust fails closed when
/// this is absent or still an unsubstituted placeholder.
internal let sojournDevelopmentTeamInfoKey = "SojournDevelopmentTeam"

/// Daemon launchd plist filename inside the app's
/// `Contents/Library/LaunchDaemons/` directory.
internal let masHelperLaunchdPlistName = "industries.bizarre.Sojourn.helper.plist"

/// XPC contract surfaced by the privileged helper. All methods are
/// fire-and-reply — NSXPCConnection requires `@escaping` reply blocks
/// because the runtime cannot bridge Swift `async` across XPC.
@objc(MasHelperProtocol)
internal protocol MasHelperProtocol {
  /// Run `mas install <id>` as root.
  /// Reply: (exitCode, stdoutUTF8, stderrUTF8). exitCode == 0 on
  /// success; helper-side timeout (`masHelperTimeoutSeconds`)
  /// produces exitCode == `masHelperTimeoutExitCode`.
  func install(
    appStoreID: NSNumber,
    withReply reply: @escaping (Int32, String, String) -> Void
  )

  /// Run `mas upgrade [<id1> <id2> ...]` as root.
  /// Empty array means "upgrade everything". Reply same shape as
  /// install. Helper-side timeout produces exitCode == `masHelperTimeoutExitCode`.
  func upgrade(
    appStoreIDs: [NSNumber],
    withReply reply: @escaping (Int32, String, String) -> Void
  )

  /// Cheap liveness probe. Returns the helper's CFBundleVersion so
  /// the client can detect a stale helper after Sojourn upgrades.
  func helperVersion(
    withReply reply: @escaping (String) -> Void
  )
}

/// Helper-side hard cap on `mas install` / `mas upgrade` per
/// JobRunner snapshot tier. ADR-0024 + v0.3-plan.md §"Hard decisions".
internal let masHelperTimeoutSeconds: TimeInterval = 600

/// Sentinel exit code returned by the helper when its 600s cap fires
/// before the subprocess exits. Distinct from any code `mas` itself
/// could emit (which is unsigned 0-255).
internal let masHelperTimeoutExitCode: Int32 = -2

/// Sentinel exit code returned by the helper when client validation
/// rejects the input (e.g. `appStoreID == 0`).
internal let masHelperInvalidInputExitCode: Int32 = -3

/// Sentinel exit code returned when the root helper refuses to execute
/// a user-writable or otherwise untrusted `mas` binary.
internal let masHelperUntrustedToolExitCode: Int32 = -4

/// Helper-side path to `mas`. Hardcoded — the helper runs as root
/// with a minimal PATH, so we cannot rely on PATH lookup. Apple
/// Silicon Homebrew prefix.
internal let masHelperToolPath = "/opt/homebrew/bin/mas"

internal func sojournDevelopmentTeamID(from bundle: Bundle = .main) -> String? {
  guard let raw = bundle.object(forInfoDictionaryKey: sojournDevelopmentTeamInfoKey) as? String else {
    return nil
  }
  let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty, !trimmed.contains("$("), !trimmed.contains(")") else {
    return nil
  }
  return trimmed
}

internal func masHelperAuthorizedClientRequirement(teamID: String) -> String {
  """
  anchor apple generic \
  and identifier "\(masHelperAuthorizedClientIdentifier)" \
  and certificate 1[field.1.2.840.113635.100.6.2.6] /* Developer ID intermediate */ \
  and certificate leaf[field.1.2.840.113635.100.6.1.13] /* Developer ID Application */ \
  and certificate leaf[subject.OU] = "\(teamID)"
  """
}

internal func masHelperClientRequirement(teamID: String) -> String {
  """
  anchor apple generic \
  and identifier "\(masHelperBundleIdentifier)" \
  and certificate 1[field.1.2.840.113635.100.6.2.6] \
  and certificate leaf[field.1.2.840.113635.100.6.1.13] \
  and certificate leaf[subject.OU] = "\(teamID)"
  """
}
