# IPC, not linking — the licensing firewall

Sojourn is GPL-3.0-or-later. The original v0.1 risk was `mpm`, a
GPL-2.0-only tool; ADR-0018 later removed that backend, but the firewall
remains the rule for every operational CLI. Sojourn keeps tools at arm's
length: separate process, argv in, structured stdout out, exit code back.
The decision is recorded immutably in
[decisions/0001-ipc-not-linking.md](../decisions/0001-ipc-not-linking.md);
this page is the explanatory companion.

## Why this matters

GPL-3.0-or-later and GPL-2.0-only are **incompatible** for combined
works. The GPL combined-work test is structural — code linked into the
same address space at runtime is one work. If Sojourn linked a GPL-2.0-only
backend (the old `mpm` plan, or a future equivalent), the resulting binary
would be a derivative of GPL-2.0-only code, and Sojourn could not ship under
GPL-3 anymore.

Re-licensing options would close at the same time:

- **AGPL-3.0** is incompatible with GPL-2.0-only. Linking forecloses
  ever moving Sojourn to AGPL if a future release adds a hosted
  service.
- **MPL-2.0** would require GPL-2.0 component isolation, which Swift
  packages don't structurally provide.
- **GPL-2.0-or-later** would work, but it lacks GPL-3's
  anti-tivoization and patent-retaliation clauses, which matter for a
  signed macOS app shipping in the post-DMA era.

## What "IPC, not linking" means in practice

Sojourn invokes every external CLI through `SubprocessRunner`:

- `Process` from `Foundation` (or `swift-subprocess`).
- argv as the input contract.
- stdout / stderr as a `Pipe`-backed `AsyncStream<Data>`.
- exit code as the success signal.

There is no `dlopen`, no static archive embedded, no Swift wrapper that
imports the backend's source, no thread sharing. The Swift Package
manifest contains zero dependencies that pull in CLI backend source such as
`chezmoi`, `gitleaks`, or `age`.

The FSF GPL FAQ recognises this exact pattern as **mere aggregation**:
two programs that communicate via "pipes, sockets, and command-line
arguments" are separate works for license purposes, regardless of
whether they ship in the same install bundle.

## What "IPC, not linking" forbids

Reviewers reject these patterns even when they look small:

- A Swift package that wraps `libgit2` for "performance" — linked C
  library, GPL-bypass attempt that wouldn't survive an audit.
- An mpm Python module imported via `PythonKit` — runs in-process,
  defeats the firewall.
- Embedding `chezmoi` source as Go-via-cgo — linked.
- Adding `SwiftShell` or `ShellOut` as a transitive dep — those
  packages run subprocesses but their unmaintained status creates a
  different problem (see [AGENTS.md](../../AGENTS.md) "Do not do" list).

The acid test: if the entire backend disappeared at runtime (binary
unlinked, file deleted), would Sojourn crash? If yes, it's linked. If
Sojourn would just fail a "tool not found" job, the firewall holds.

## Bundled binaries are not linked binaries

Sojourn ships `gitleaks` and `age` in `Contents/Resources/bin/`. Both
are MIT-licensed. They are bundled, not linked: Sojourn invokes them
via `Process`, not `dlopen`. This works the same way `git` (system) or
`brew` (user-installed) does — the binary lives somewhere and Sojourn
shells to it.

The bundled-binary policy is in
[decisions/0009-bundle-binary-policy.md](../decisions/0009-bundle-binary-policy.md).
The provenance flow (download via authenticated `gh release download`,
re-sign under `--options=runtime`, cover by `.app` notarization, gate
on `spctl --assess`) is in
[explain/threat-model.md](threat-model.md).

## Future re-licensing optionality

GPL-3.0-or-later was chosen partly for the **upgrade clause**. If
Sojourn ever adds a hosted server component (e.g. an opt-in fleet
sync), the project can move to AGPL-3.0 without re-coordinating
contributor rights — the "or-later" clause already permits it.

Linking a GPL-2.0-only backend would close this door permanently. The IPC
firewall keeps it open.

## See also

- [decisions/0001-ipc-not-linking.md](../decisions/0001-ipc-not-linking.md)
  — the formal decision record.
- [decisions/0004-gpl-3-or-later.md](../decisions/0004-gpl-3-or-later.md)
  — license choice.
- [reference/licensing.md](../reference/licensing.md) — full per-component
  license table.
- [decisions/0007-shell-out-to-git.md](../decisions/0007-shell-out-to-git.md)
  — same firewall logic for `git` (avoiding libgit2).
- [AGENTS.md](../../AGENTS.md) "Do not do" — the non-negotiable list.
