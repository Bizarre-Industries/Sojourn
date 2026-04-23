import Foundation
import Observation

/// Root Observable store. See docs/ARCHITECTURE.md section 11.
@Observable
final class AppStore {
  var settings: Settings = Settings()
  var bootstrapState: BootstrapState = .unknown
  var toolInventory: ToolInventory = .empty
  var lastError: AppError?

  init() {}
}

enum BootstrapState: Sendable, Equatable {
  case unknown
  case probingSystem
  case reportingStatus
  case awaitingUserConsent
  case installingCLT
  case installingBrew
  case installingMpm
  case installingChezmoi
  case ready
  case failed(String)
}

struct AppError: Error, Sendable, Equatable {
  let message: String
}
