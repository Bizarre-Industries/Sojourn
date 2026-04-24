// Sojourn — Logging
//
// Thin wrapper over `os.Logger` with the six category namespaces declared
// in docs/ARCHITECTURE.md §18. Every service uses these categories so
// Console.app / Instruments filter cleanly.

import Foundation
import OSLog

internal enum SojournLog {
  internal static let subsystem = "app.bizarre.sojourn"

  internal static let sync        = Logger(subsystem: subsystem, category: "sync")
  internal static let subprocess  = Logger(subsystem: subsystem, category: "subprocess")
  internal static let bootstrap   = Logger(subsystem: subsystem, category: "bootstrap")
  internal static let secrets     = Logger(subsystem: subsystem, category: "secrets")
  internal static let cleanup     = Logger(subsystem: subsystem, category: "cleanup")
  internal static let ui          = Logger(subsystem: subsystem, category: "ui")
  internal static let persistence = Logger(subsystem: subsystem, category: "persistence")
}

/// Instruments-visible signposter for coarse-grained phase timing.
/// Keep regions short (< a few seconds) so the Instruments view is useful.
internal enum SojournSignpost {
  internal static let sync = OSSignposter(
    subsystem: SojournLog.subsystem, category: "sync"
  )
  internal static let bootstrap = OSSignposter(
    subsystem: SojournLog.subsystem, category: "bootstrap"
  )
}
