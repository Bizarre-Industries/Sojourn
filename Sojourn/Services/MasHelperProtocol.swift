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

/// Helper-side path to `mas`. Hardcoded — the helper runs as root
/// with a minimal PATH, so we cannot rely on PATH lookup. Apple
/// Silicon Homebrew prefix.
internal let masHelperToolPath = "/opt/homebrew/bin/mas"
