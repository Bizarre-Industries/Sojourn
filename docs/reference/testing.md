# Testing

Sojourn's test contract is fixture-backed and Apple-first.

## Unit tests

Every `Service` actor ships with a `.mock(response:)` factory that takes a
`@Sendable (Args) -> Data` closure. Tests inject fixture JSON/TOML from
`SojournTests/Fixtures/`. **No live brew, chezmoi, or network calls in unit
tests.**

## Integration tests

`SyncCoordinatorTests` spin up a local bare git repo under
`FileManager.default.temporaryDirectory` and drive a full push cycle.
`DeletionsDBTests` use a temp SQLite file. Nothing outside of
`FileManager.default.temporaryDirectory` is mutated.

## Snapshot-of-UI tests (Phase 9)

Compare logical accessibility snapshots, not raw screenshots. Every view
that users navigate to has an `.accessibilityIdentifier("…")` declared; UI
tests assert on those strings rather than pixels.

## No stdout-snapshot tests

Per AGENTS.md, subprocess output is unstable across minor versions.

## Coverage target

Unit + integration combined ≥ 75% line coverage on `Sojourn/` excluding
`UI/`. UI coverage is logical-accessibility only.

## Test tooling

Swift Testing (`import Testing`, `@Test`) for new tests. Pre-existing
XCTest stays. See [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Fixture maintenance

Fixtures under `SojournTests/Fixtures/` are checked-in golden files of real
brew, chezmoi, git, and helper-tool output. Update the fixtures when upstream
output changes; do not generate them on the fly. See
[AGENTS.md](../../AGENTS.md) "Test requirements" for the policy.
