# State management — `@Observable`, not TCA

The Observation framework (macOS 14+) solves the problems TCA was invented
for. TCA adds 24-releases-in-a-year churn, macro-property-wrapper friction,
a giant-state-struct pattern that fights SwiftUI at scale, and collaborator
ramp. Sojourn's state is almost entirely derived from parsed JSON
subprocess output — TCA's action/reducer ceremony is low-value here.

The decision is recorded in
[decisions/0005-no-tca.md](../decisions/0005-no-tca.md).

## Root store

```swift
@Observable final class AppStore {
    var settings: Settings = .load()
    var managers: [ManagerID: ManagerSnapshot] = [:]
    var history: [HistoryEntry] = []
    var bootstrapState: BootstrapState = .unknown
    var activeJobs: [JobID: Job] = [:]
    var lastError: AppError?
    var toolInventory: ToolInventory = .empty
}
```

Injected once at `App`, read with `@Environment(AppStore.self)`. Use
`@Bindable` for two-way bindings into UI. Beware Jesse Squires'
`@State + @Observable` initialization gotcha: always create the root store
at app level, never at view level.

## Why not TCA

- TCA's giant-state-struct fights SwiftUI's per-view diff invalidation.
  Observation is fine-grained for free.
- 24+ TCA releases per year creates a maintenance burden the project does
  not want to pay.
- Sojourn's state is mostly server-derived (subprocess JSON output). The
  reducer pattern is heavy ceremony for "decode this JSON into the store".
- Onboarding new contributors should not require learning a third-party
  state framework when Apple ships one that fits.

## Why not raw `@StateObject` / Combine

`@Observable` (Observation framework) is the 2024 replacement for those.
We're targeting macOS 14+ — the framework is available — so we use it.
