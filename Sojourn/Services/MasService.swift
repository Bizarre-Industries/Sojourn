// Sojourn — MasService
//
// High-level wrapper over `MasHelperClient` + SMAppService daemon
// lifecycle. Surfaces helper register/unregister/status to the UI
// (PackagesPane status row + Revoke button) and forwards
// install/upgrade calls to the privileged helper.
//
// Per ADR-0024 + council 2026-05-03:
// - Registration uses `SMAppService.daemon(plistName:).register()`
//   (post-macOS 13 path). User sees one Touch-ID / authentication
//   prompt the first time; subsequent calls go through XPC silently
//   (gated by `SMAuthorizedClients` install-time check + per-XPC
//   client-side `setCodeSigningRequirement` check).
// - Revoke calls `unregister()` and removes the launchd plist.
// - Status surfaces the SMAppService.Status enum so the PackagesPane
//   row can render "active" / "needs approval" / "not installed".

import Foundation
import OSLog
import ServiceManagement

internal enum MasHelperStatus: String, Sendable, Equatable {
  /// Never registered, or unregistered + cleaned up.
  case notRegistered
  /// Registered + launchd will spawn the helper on demand.
  case registered
  /// User must approve in System Settings → General → Login Items.
  case requiresApproval
  /// SMAppService returned `.notFound` — likely the daemon plist is
  /// missing from the app bundle (build configuration drift).
  case missing
  /// SMAppService returned an unrecognized state.
  case unknown
}

internal enum MasServiceError: Error, Sendable, CustomStringConvertible {
  case registrationFailed(String)
  case unregistrationFailed(String)
  case helperError(MasHelperClientError)
  case invocationFailed(exitCode: Int32, stderr: String)

  internal var description: String {
    switch self {
    case .registrationFailed(let msg):
      return "MasHelper registration failed: \(msg)"
    case .unregistrationFailed(let msg):
      return "MasHelper unregistration failed: \(msg)"
    case .helperError(let err):
      return "MasHelper client error: \(err.description)"
    case .invocationFailed(let code, let stderr):
      let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
      return "mas exited \(code): \(trimmed)"
    }
  }
}

internal actor MasService {
  private let log = Logger(
    subsystem: "app.bizarre.sojourn",
    category: "MasService"
  )
  private let client: MasHelperClient
  private let daemon: SMAppService

  internal init(client: MasHelperClient = MasHelperClient()) {
    self.client = client
    self.daemon = SMAppService.daemon(plistName: masHelperLaunchdPlistName)
  }

  // MARK: - Lifecycle

  /// Register the privileged helper. macOS prompts the user if the
  /// helper is not already approved. Idempotent — calling on an
  /// already-registered helper is a no-op.
  internal func register() throws {
    do {
      try daemon.register()
      log.notice("MasHelper registered")
    } catch {
      log.error("MasHelper register failed: \(error.localizedDescription, privacy: .public)")
      throw MasServiceError.registrationFailed(error.localizedDescription)
    }
  }

  /// Unregister + invalidate the XPC connection. Cask uninstall
  /// removes the daemon plist from `/Library/LaunchDaemons/` via
  /// SMAppService.unregister; the cask's `delete:` stanza handles
  /// any remaining file cleanup.
  internal func unregister() async throws {
    await client.invalidate()
    do {
      try await daemon.unregister()
      log.notice("MasHelper unregistered")
    } catch {
      log.error("MasHelper unregister failed: \(error.localizedDescription, privacy: .public)")
      throw MasServiceError.unregistrationFailed(error.localizedDescription)
    }
  }

  internal func status() -> MasHelperStatus {
    switch daemon.status {
    case .notRegistered:    return .notRegistered
    case .enabled:          return .registered
    case .requiresApproval: return .requiresApproval
    case .notFound:         return .missing
    @unknown default:       return .unknown
    }
  }

  // MARK: - Helper invocations (forwarded to MasHelperClient)

  internal func install(appStoreID: UInt64) async throws -> MasInvocationResult {
    do {
      let result = try await client.install(appStoreID: appStoreID)
      if !result.didSucceed {
        log.error("install id=\(appStoreID) exited \(result.exitCode)")
      }
      return result
    } catch let err as MasHelperClientError {
      throw MasServiceError.helperError(err)
    }
  }

  internal func upgrade(appStoreIDs: [UInt64] = []) async throws -> MasInvocationResult {
    do {
      let result = try await client.upgrade(appStoreIDs: appStoreIDs)
      if !result.didSucceed {
        log.error("upgrade exited \(result.exitCode)")
      }
      return result
    } catch let err as MasHelperClientError {
      throw MasServiceError.helperError(err)
    }
  }

  internal func helperVersion() async throws -> String {
    do {
      return try await client.helperVersion()
    } catch let err as MasHelperClientError {
      throw MasServiceError.helperError(err)
    }
  }
}
