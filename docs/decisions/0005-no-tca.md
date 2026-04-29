# 0005 — Use raw `@Observable`; do not adopt The Composable Architecture

- **Status**: Accepted
- **Date**: 2026-04-24
- **Deciders**: Sojourn maintainer

## Context

The Observation framework (macOS 14+, Sojourn's deployment floor) provides
fine-grained dependency tracking that solves the SwiftUI invalidation
problem TCA was originally invented for. TCA adds substantial complexity:
a giant single-state-struct pattern, action/reducer ceremony,
macro-property-wrapper friction, and a ~24-releases-per-year update cadence
that competes for review bandwidth.

Sojourn's state is dominated by parsed JSON subprocess output. Reducer
ceremony for "decode JSON, store in property" is heavy without proportional
benefit.

## Decision

The root `AppStore` is a single `@Observable final class` injected once at
the `App` level via `.environment` and read with
`@Environment(AppStore.self)`. Two-way bindings use `@Bindable`. No TCA;
no third-party state framework.

## Consequences

### Positive

- Smaller dep tree; fewer breaking-change cycles to chase.
- Onboarding new contributors does not require learning a custom state
  framework.
- SwiftUI's per-view diff invalidation works as designed against
  `@Observable` properties.

### Negative

- No reducer-as-pure-function pattern; tests have to instantiate the
  store and exercise it.
- No built-in time-travel debugging.

### Neutral

- The architectural invariant (root store at `App` level, never `@State`
  inside a view) is enforced by code review.

## Alternatives considered

- **TCA (`swift-composable-architecture`)** — rejected. See Context.
- **Combine + `@StateObject`** — rejected. Apple's own replacement
  (Observation) is available on the deployment target.
- **Redux-style external library** — rejected. Same reasoning as TCA;
  third-party churn unwarranted for the project size.
