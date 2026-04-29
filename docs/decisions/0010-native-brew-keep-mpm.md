# 0010 — Selectively native brew/cask/mas; keep mpm for the rest

- **Status**: Proposed (lands in implementation-plan phase 10/13)
- **Date**: 2026-04-28
- **Deciders**: Sojourn maintainer

## Context

The audit
[process/audit-2026-04.md §2.3](../process/audit-2026-04.md#23-native-replacement-decisions)
analyzed which managers benefit from native Swift implementations vs
staying behind mpm:

- **Native wins**: brew (~80% of installed packages on a Mac dev machine,
  stable JSON API, unlocks taps + services + Brewfile interop), cask
  (same CLI as brew, exposes `artifact_dependencies`), mas (~80 LOC).
- **Native is a wash**: cargo, vscode (mpm is no slower).
- **mpm earns its keep**: pip, pipx, uvx (interpreter resolution,
  `--user` / `--break-system-packages` semantics), npm, yarn (workspaces,
  lifecycle-script gating, registry auth), gem, composer (scope-mismatch
  bugs are real — mpm's `gem` fix #389 removed `--user-install` so
  list/outdated scopes match), cargo (no outdated either way; equal cost).

mpm is a single-maintainer project (per
[explain/risks.md](../explain/risks.md) §2). Moving the highest-traffic
managers off the bus-factor risk is meaningful.

## Decision

Implement native `BrewService`, `CaskService`, `MasService` as actors
parallel to `MPMService`. Keep `MPMService` for pip, pipx, uvx, npm, yarn,
gem, composer, cargo, vscode.

Introduce a `PackageBackend` protocol (audit §3.2.1, lands in
implementation-plan phase 10) so `JobRunner` and `SyncCoordinator` work
against the protocol, not the concrete actor. This makes the swap
transparent to call sites and unblocks the plugin protocol
([0013-out-of-process-plugins.md](0013-out-of-process-plugins.md)).

## Consequences

### Positive

- Bus-factor risk reduced for the dominant manager.
- Brew taps + services capture (audit §2.4.1, §2.4.2) becomes possible
  natively (mpm doesn't surface them).
- Brewfile interop available for users migrating from `brew bundle`.

### Negative

- Three new actors to maintain. Each duplicates testing surface.
- Risk of behaviour drift between `BrewService` and `mpm --brew`.
  Mitigation: snapshot tests against the same fixtures.

### Neutral

- Packages registry (`packages.toml`) format unchanged — still mpm's
  TOML output. Native services emit the same shape.

## Alternatives considered

- **All-native** — rejected. Reimplements years of pip/npm/gem
  scope-handling fixes that mpm already absorbs.
- **All-mpm** — rejected. Leaves taps + services + Brewfile interop on
  the floor and keeps the bus-factor exposure on 80% of traffic.
- **Native only for brew (drop cask + mas)** — rejected. Cask shares the
  brew CLI; mas is ~80 LOC. Both for free once `BrewService` exists.
