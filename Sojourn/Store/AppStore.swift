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
public final class AppStore {
  public let runner: SubprocessRunner
  public let jobRunner: JobRunner
  public let toolLocator: ToolLocator

  public var managers: [String: ManagerSnapshot] = [:]

  public init() {
    let runner = SubprocessRunner()
    self.runner = runner
    self.jobRunner = JobRunner(runner: runner)
    self.toolLocator = ToolLocator()
  }
}
