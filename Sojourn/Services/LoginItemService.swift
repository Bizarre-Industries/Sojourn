// Sojourn — LoginItemService
//
// Thin ServiceManagement wrapper for the user-facing "launch Sojourn at
// login" preference. UI reads AppStore state and dispatches through this
// service; views never call SMAppService directly.

import Foundation
import OSLog
import ServiceManagement

internal enum LoginItemStatus: Sendable, Equatable {
  case notRegistered
  case enabled
  case requiresApproval
  case notFound
  case unknown

  internal var label: String {
    switch self {
    case .notRegistered: "Off"
    case .enabled: "On"
    case .requiresApproval: "Needs approval"
    case .notFound: "Unavailable"
    case .unknown: "Unknown"
    }
  }

  internal var detail: String {
    switch self {
    case .notRegistered:
      "Sojourn will not open automatically after you sign in."
    case .enabled:
      "macOS will open Sojourn after you sign in."
    case .requiresApproval:
      "Approve Sojourn in System Settings > General > Login Items."
    case .notFound:
      "macOS could not find this app as a login item candidate."
    case .unknown:
      "Sojourn could not read the macOS login item status."
    }
  }

  internal var isEnabledForToggle: Bool {
    switch self {
    case .enabled, .requiresApproval: true
    case .notRegistered, .notFound, .unknown: false
    }
  }
}

internal enum LoginItemServiceError: Error, Sendable, CustomStringConvertible {
  case registrationFailed(String)
  case unregistrationFailed(String)

  internal var description: String {
    switch self {
    case .registrationFailed(let msg): "Login item registration failed: \(msg)"
    case .unregistrationFailed(let msg): "Login item removal failed: \(msg)"
    }
  }
}

internal protocol LoginItemServicing: Sendable {
  func register() async throws
  func unregister() async throws
  func status() async -> LoginItemStatus
}

internal actor LoginItemService: LoginItemServicing {
  private let log = Logger(
    subsystem: "app.bizarre.sojourn",
    category: "LoginItemService"
  )
  private let app: SMAppService

  internal init(app: SMAppService = .mainApp) {
    self.app = app
  }

  internal func register() async throws {
    do {
      try app.register()
      log.notice("Login item registered")
    } catch {
      log.error("Login item register failed: \(error.localizedDescription, privacy: .public)")
      throw LoginItemServiceError.registrationFailed(error.localizedDescription)
    }
  }

  internal func unregister() async throws {
    do {
      try await app.unregister()
      log.notice("Login item unregistered")
    } catch {
      log.error("Login item unregister failed: \(error.localizedDescription, privacy: .public)")
      throw LoginItemServiceError.unregistrationFailed(error.localizedDescription)
    }
  }

  internal func status() async -> LoginItemStatus {
    switch app.status {
    case .notRegistered: .notRegistered
    case .enabled: .enabled
    case .requiresApproval: .requiresApproval
    case .notFound: .notFound
    @unknown default: .unknown
    }
  }
}
