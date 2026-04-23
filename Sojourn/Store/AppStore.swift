// Sojourn — AppStore
//
// The single `@Observable` root state container. Owned by `SojournApp` at
// the `@main` level; injected via `.environment(appStore)` and read via
// `@Environment(AppStore.self)`. Never `@State` at the root — see CLAUDE.md
// "Do not use @State to hold the root AppStore."
//
// Phase 1 skeleton: holds `JobRunner` and `ToolLocator` only. Phase 2
// extends with Settings, persistence, per-manager snapshots, history.

import Foundation
import Observation

@Observable
@MainActor
internal final class AppStore {
  internal let runner: SubprocessRunner
  internal let jobRunner: JobRunner
  internal let toolLocator: ToolLocator

  internal var managers: [String: ManagerSnapshot] = [:]

  internal init() {
    let runner = SubprocessRunner()
    self.runner = runner
    self.jobRunner = JobRunner(runner: runner)
    self.toolLocator = ToolLocator()
  }
}
