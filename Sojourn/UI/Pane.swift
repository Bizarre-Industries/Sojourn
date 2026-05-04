// Sojourn — Pane

import Foundation

internal enum Pane: String, Hashable, CaseIterable, Identifiable {
  case dashboard
  case packages
  case containers
  case generations
  case macosFeatures
  case preferences
  case sync
  case machines
  case advisories
  case jobs
  case settings

  internal var id: String { rawValue }

  internal var label: String {
    switch self {
    case .dashboard:     return "Overview"
    case .packages:      return "Packages"
    case .containers:    return "Containers"
    case .generations:   return "Generations"
    case .macosFeatures: return "macOS Features"
    case .preferences:   return "Preferences"
    case .sync:          return "Sync"
    case .machines:      return "Machines"
    case .advisories:    return "Advisories"
    case .jobs:          return "Jobs"
    case .settings:      return "Settings"
    }
  }

  internal var icon: String {
    switch self {
    case .dashboard:     return "gauge.with.dots.needle.bottom.50percent"
    case .packages:      return "shippingbox"
    case .containers:    return "cube.box"
    case .generations:   return "clock.arrow.circlepath"
    case .macosFeatures: return "switch.2"
    case .preferences:   return "slider.horizontal.3"
    case .sync:          return "arrow.triangle.2.circlepath"
    case .machines:      return "laptopcomputer.and.iphone"
    case .advisories:    return "exclamationmark.shield"
    case .jobs:          return "terminal"
    case .settings:      return "gear"
    }
  }

  internal static let operations: [Pane] = [
    .dashboard, .packages, .containers, .generations
  ]

  internal static let configuration: [Pane] = [
    .macosFeatures, .preferences, .sync, .machines
  ]

  internal static let maintenance: [Pane] = [
    .advisories, .jobs, .settings
  ]
}
