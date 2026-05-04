// Sojourn — MasHelperClient
//
// XPC client wrapping NSXPCConnection to the privileged MasHelper.
// Bridges the `@objc` reply-block protocol to Swift `async throws`
// via `withCheckedThrowingContinuation`.
//
// Per ADR-0024 + council 2026-05-03:
// - Per-connection client-side `setCodeSigningRequirement(_:)` so the
//   client refuses to talk to a tampered helper. Symmetric to the
//   helper's per-connection check.
// - DEBUG builds skip the requirement (no Developer ID locally).
// - Single shared `NSXPCConnection` per actor lifetime; XPC handles
//   reconnect transparently if the helper is restarted.

import Foundation
import OSLog

internal struct MasInvocationResult: Sendable, Equatable {
  internal let exitCode: Int32
  internal let stdout: String
  internal let stderr: String

  internal var didSucceed: Bool { exitCode == 0 }
  internal var didTimeOut: Bool { exitCode == masHelperTimeoutExitCode }
  internal var didReject: Bool  { exitCode == masHelperInvalidInputExitCode }
}

internal enum MasHelperClientError: Error, Sendable, Equatable, CustomStringConvertible {
  case connectionFailed(String)
  case invalidProxyShape
  case invalidAppStoreID(UInt64)
  case helperUnreachable(String)

  internal var description: String {
    switch self {
    case .connectionFailed(let msg):  return "XPC connection failed: \(msg)"
    case .invalidProxyShape:          return "XPC proxy did not conform to MasHelperProtocol"
    case .invalidAppStoreID(let id):  return "invalid App Store ID: \(id)"
    case .helperUnreachable(let msg): return "MasHelper unreachable: \(msg)"
    }
  }
}

internal actor MasHelperClient {
  private let log = Logger(
    subsystem: "app.bizarre.sojourn",
    category: "MasHelperClient"
  )

  private var connection: NSXPCConnection?

  internal init() {}

  // MARK: - Public API

  internal func install(appStoreID: UInt64) async throws -> MasInvocationResult {
    guard appStoreID > 0 else {
      throw MasHelperClientError.invalidAppStoreID(appStoreID)
    }
    return try await withProxy { proxy, continuation in
      proxy.install(appStoreID: NSNumber(value: appStoreID)) { code, stdout, stderr in
        continuation.resume(returning: MasInvocationResult(
          exitCode: code, stdout: stdout, stderr: stderr
        ))
      }
    }
  }

  internal func upgrade(appStoreIDs: [UInt64]) async throws -> MasInvocationResult {
    for id in appStoreIDs where id == 0 {
      throw MasHelperClientError.invalidAppStoreID(0)
    }
    let nsIDs = appStoreIDs.map { NSNumber(value: $0) }
    return try await withProxy { proxy, continuation in
      proxy.upgrade(appStoreIDs: nsIDs) { code, stdout, stderr in
        continuation.resume(returning: MasInvocationResult(
          exitCode: code, stdout: stdout, stderr: stderr
        ))
      }
    }
  }

  internal func helperVersion() async throws -> String {
    try await withProxyString { proxy, continuation in
      proxy.helperVersion { version in
        continuation.resume(returning: version)
      }
    }
  }

  internal func invalidate() {
    connection?.invalidate()
    connection = nil
  }

  // MARK: - Connection management

  private func ensureConnection() throws -> NSXPCConnection {
    if let connection { return connection }
    let conn = NSXPCConnection(machServiceName: masHelperMachServiceName, options: .privileged)
    conn.remoteObjectInterface = NSXPCInterface(with: MasHelperProtocol.self)
#if !DEBUG
    let requirement = """
      anchor apple generic \
      and identifier "\(masHelperBundleIdentifier)" \
      and certificate 1[field.1.2.840.113635.100.6.2.6] \
      and certificate leaf[field.1.2.840.113635.100.6.1.13]
      """
    do {
      try conn.setCodeSigningRequirement(requirement)
    } catch {
      throw MasHelperClientError.connectionFailed(
        "code-signing requirement rejected: \(error.localizedDescription)"
      )
    }
#endif
    conn.invalidationHandler = { [weak self] in
      Task { [weak self] in await self?.handleInvalidation() }
    }
    conn.interruptionHandler = { [weak self] in
      Task { [weak self] in await self?.handleInvalidation() }
    }
    conn.resume()
    connection = conn
    return conn
  }

  private func handleInvalidation() {
    connection = nil
    log.notice("XPC connection invalidated; will reconnect on next call")
  }

  // MARK: - Proxy helpers

  private typealias TupleContinuation = CheckedContinuation<MasInvocationResult, any Error>

  private func withProxy(
    _ body: @escaping (any MasHelperProtocol, TupleContinuation) -> Void
  ) async throws -> MasInvocationResult {
    let conn = try ensureConnection()
    return try await withCheckedThrowingContinuation { (continuation: TupleContinuation) in
      let proxy = conn.remoteObjectProxyWithErrorHandler { error in
        continuation.resume(throwing: MasHelperClientError.helperUnreachable(error.localizedDescription))
      }
      guard let typedProxy = proxy as? MasHelperProtocol else {
        continuation.resume(throwing: MasHelperClientError.invalidProxyShape)
        return
      }
      body(typedProxy, continuation)
    }
  }

  private typealias StringContinuation = CheckedContinuation<String, any Error>

  private func withProxyString(
    _ body: @escaping (any MasHelperProtocol, StringContinuation) -> Void
  ) async throws -> String {
    let conn = try ensureConnection()
    return try await withCheckedThrowingContinuation { (continuation: StringContinuation) in
      let proxy = conn.remoteObjectProxyWithErrorHandler { error in
        continuation.resume(throwing: MasHelperClientError.helperUnreachable(error.localizedDescription))
      }
      guard let typedProxy = proxy as? MasHelperProtocol else {
        continuation.resume(throwing: MasHelperClientError.invalidProxyShape)
        return
      }
      body(typedProxy, continuation)
    }
  }
}
