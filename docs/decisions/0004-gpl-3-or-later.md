# 0004 — Sojourn is licensed GPL-3.0-or-later

- **Status**: Accepted
- **Date**: 2026-04-24
- **Deciders**: Sojourn maintainer

## Context

Sojourn is a desktop app that wraps GPL-2.0-only (`mpm`), MIT (`chezmoi`,
`gitleaks`, `age`), BSD-2 (`brew`), and Apple-proprietary (`defaults`)
tools via subprocess invocation only (see
[0001-ipc-not-linking.md](0001-ipc-not-linking.md)).

The license choice has to:

1. Allow distributing a notarized macOS DMG.
2. Stay copyleft to align with the maintainer's project values.
3. Not paint Sojourn into a corner that prevents future architectural
   evolution (e.g., a hosted server component).
4. Coexist with GPL-2.0-only `mpm` while the IPC-not-linking invariant
   holds.

## Decision

Sojourn is **GPL-3.0-or-later** with the IPC-not-linking invariant
documented in [0001-ipc-not-linking.md](0001-ipc-not-linking.md).

The "or-later" clause preserves the option to migrate upward to AGPL-3.0
if Sojourn ever grows a server component, or to keep tracking GPL evolution
without re-licensing the codebase.

## Consequences

### Positive

- Anti-tivoization clause (GPL-3 §3) protects against signed-binary
  lockdown — important on macOS where Apple enforces signing.
- Patent-retaliation clause (GPL-3 §11) gives contributors stronger
  protection.
- Compatible with the rest of the stack: Homebrew (BSD-2), chezmoi (MIT),
  gitleaks (MIT), age (MIT), Mackup `applications/` registry (GPL-3).
- "or-later" leaves the door open for AGPL upgrade.

### Negative

- Some commercial integrators avoid GPL-3 entirely. Sojourn is a finished
  shipping app, not a library, so this matters less.
- AGPL upgrade is one-way; downgrading from a future AGPL choice back to
  GPL-3 would not be possible.

### Neutral

- The Mackup-derived `data/applications/` registry is GPL-3-or-later;
  inherited from upstream and properly attributed in
  [reference/third-party.md](../reference/third-party.md).

## Alternatives considered

- **AGPL-3.0** — rejected. Sojourn is a desktop app, not a network
  service. AGPL §13's network-disclosure obligations don't benefit
  desktop users. Also incompatible with GPL-2.0-only mpm if linked, which
  closes a future option.
- **GPL-2.0-or-later** — rejected. Lacks GPL-3's anti-tivoization and
  patent-retaliation clauses, both relevant for signed-and-notarized
  macOS distribution.
- **MPL-2.0** — rejected. Sojourn is a finished app, not a library
  primarily intended for proprietary integration. MPL's file-scoped weak
  copyleft is a better fit for libraries.
- **Apache-2.0** — rejected. Not copyleft; conflicts with project values.
