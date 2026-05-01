# 0001 — Sojourn invokes external CLIs via IPC, never via library linking

- **Status**: Accepted
- **Date**: 2026-04-24
- **Deciders**: Sojourn maintainer

## Context

Sojourn wraps `mpm` (GPL-2.0-only), `chezmoi` (MIT), `git` (GPL-2.0), `brew`
(BSD-2), `gitleaks` (MIT), `age` (MIT), and Apple's `defaults` / `plutil`.
The license mix is incompatible with naive combination — most importantly,
GPL-2.0-only is not compatible with GPL-3.0-or-later or AGPL-3.0 if linked
into the same combined work.

The FSF GPL FAQ recognises arm's-length subprocess interaction (pipes, exit
codes, argv, structured stdout) as **mere aggregation** — does not trigger
combined-work obligations.

## Decision

Sojourn invokes `mpm`, `chezmoi`, `git`, `brew`, `gitleaks`, `age`, and
`defaults` as **separate processes**, communicating only via:

- Command-line arguments (argv).
- Structured stdout/stderr (JSON, TOML, plaintext).
- Exit codes.

Sojourn does **not**:

- Link any of the above as libraries (no `dlopen`, static archive, or
  shared address space).
- Embed their source code into the app bundle.
- Run them as threads inside the Sojourn process.

## Consequences

### Positive

- Sojourn (GPL-3.0-or-later) can legally invoke `mpm` (GPL-2.0-only)
  without license conflict.
- Re-licensing flexibility preserved: removing the mpm subprocess in a
  future architecture lifts the GPL-2-only constraint and re-opens AGPL or
  MPL options.
- Thinner integration surface — easier to swap a CLI for a different one
  if upstream goes unmaintained.
- Each CLI's own bug fixes propagate without Sojourn rebuilds.

### Negative

- Subprocess invocation overhead per call (typically <50ms; not a
  bottleneck because every call wraps a multi-second package operation).
- No type safety at the IPC boundary; output parsing is fragile when
  upstream output flaps (mitigated by fixture-backed tests + advisory
  parsing posture).

### Neutral

- Architectural invariant enforced via `SubprocessRunner`. PRs that add FFI
  wrappers, libgit2 bindings, or Swift packages embedding these tools' code
  are rejected at review.

## Alternatives considered

- **Link libgit2 / libssh2 / libssl** for git operations — rejected per
  [0007-shell-out-to-git.md](0007-shell-out-to-git.md). Notarisation burden
  + no LFS / SSH-agent support.
- **Embed mpm source as Swift** — rejected. mpm is GPL-2.0-only; would
  force Sojourn to GPL-2.0 and lose anti-tivoization clauses.
- **Bundle mpm/chezmoi as helper binaries** — rejected per
  [0009-bundle-binary-policy.md](0009-bundle-binary-policy.md). They update
  more often than Sojourn; bundling complicates notarisation.

---

## Amended — 2026-05-01 (v0.2 pivot)

The IPC-not-linking invariant **narrows in scope** with the v0.2 pivot
([ADR-0018](./0018-drop-mpm-for-brew-bundle.md)). `mpm` is no longer a
backend; `Sojourn/Services/MPMService.swift` and `Sojourn/Backends/`
are deleted. The remaining external CLIs Sojourn invokes via subprocess
are:

- `chezmoi` (MIT) — dotfile templating + apply
- `git` (GPL-2.0) — VCS operations (provided by Xcode CLT)
- `brew` (BSD-2-Clause) — package manager + Brewfile bundle install
- `gitleaks` (MIT) — pre-commit secret scanning (also bundled per ADR-0009)
- `age` (MIT) — chezmoi passphrase/SSH backend (also bundled per ADR-0009)
- `defaults`, `plutil`, `killall`, `xattr` (Apple) — system CLIs

The license-firewall rationale **still applies but is no longer
load-bearing for GPL-3-vs-GPL-2 compatibility**. With `mpm` removed,
Sojourn's runtime composition is GPL-3-or-later (Sojourn) +
MIT/BSD-2/Apple-system + a GPL-2.0 invocation (`git`). Subprocess
arm's-length is now an architectural hygiene rule, not a copyleft
escape valve. The original §"Why" still reads correctly for `git`,
which remains GPL-2.0.

**Re-licensing flexibility note**: With mpm gone, Sojourn could in
principle adopt AGPL-3.0 or MPL-2.0 without the GPL-2-only block.
That is a separate decision (governed by ADR-0004); this amendment
just observes that the option re-opens.

The architectural enforcement via `SubprocessRunner` and the CLAUDE.md
ban on FFI/library-linking are unchanged.

Diff source: `git log --follow docs/decisions/0001-ipc-not-linking.md`.
