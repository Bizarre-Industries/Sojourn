// MasHelper — privileged daemon entry
//
// Runs as root via SMAppService.daemon registration. Listens on the
// `industries.bizarre.Sojourn.helper.mach` mach service. Per ADR-0024
// + council 2026-05-03 amendments:
//
// - `setCodeSigningRequirement(_:)` (macOS 13+) gates EVERY incoming
//   NSXPCConnection. `SMAuthorizedClients` is install-time-only and
//   does NOT gate XPC; per-connection validation is mandatory.
// - DEBUG builds skip the requirement (Developer ID not available
//   for unsigned dev builds). Production Release builds enforce
//   strict pinning to Sojourn's Developer ID identifier.
// - The helper logs every connection + every method invocation to
//   OSLog with subsystem `industries.bizarre.Sojourn.helper` for
//   forensic recovery.
//
// Refs: docs/decisions/0024-mas-touch-id-privileged-helper.md;
//       Sojourn/Services/MasHelperProtocol.swift.

import Foundation
import OSLog

/// Subsystem used by every helper-side OSLog write.
internal let masHelperLogSubsystem = "industries.bizarre.Sojourn.helper"

internal let masHelperLog = Logger(
  subsystem: masHelperLogSubsystem,
  category: "lifecycle"
)

/// Listener delegate: gates incoming connections + wires the
/// exported interface for each accepted connection.
internal final class MasHelperListenerDelegate: NSObject, NSXPCListenerDelegate, @unchecked Sendable {

  internal func listener(
    _ listener: NSXPCListener,
    shouldAcceptNewConnection newConnection: NSXPCConnection
  ) -> Bool {
    masHelperLog.info("incoming XPC connection (pid \(newConnection.processIdentifier))")

    // Per-connection code-signing requirement. macOS 13+ API.
    // DEBUG builds skip — local dev has no Developer ID identity.
#if !DEBUG
    let requirement = """
      anchor apple generic \
      and identifier "app.bizarre.sojourn" \
      and certificate 1[field.1.2.840.113635.100.6.2.6] /* Developer ID intermediate */ \
      and certificate leaf[field.1.2.840.113635.100.6.1.13] /* Developer ID Application */
      """
    do {
      try newConnection.setCodeSigningRequirement(requirement)
    } catch {
      masHelperLog.error("code-signing requirement REJECTED connection: \(error.localizedDescription, privacy: .public)")
      return false
    }
#endif

    let interface = NSXPCInterface(with: MasHelperProtocol.self)
    newConnection.exportedInterface = interface
    newConnection.exportedObject = MasHelperService()
    newConnection.invalidationHandler = {
      masHelperLog.debug("XPC connection invalidated")
    }
    newConnection.interruptionHandler = {
      masHelperLog.debug("XPC connection interrupted")
    }
    newConnection.resume()
    return true
  }
}

masHelperLog.notice("MasHelper starting; mach service \(masHelperMachServiceName, privacy: .public)")

let listener = NSXPCListener(machServiceName: masHelperMachServiceName)
let delegate = MasHelperListenerDelegate()
listener.delegate = delegate
listener.resume()

// launchd keeps the daemon alive; we run the run loop forever.
RunLoop.current.run()
