# Design philosophy

Sojourn is opinionated about a few things. The opinions are stated here
so contributors can apply them to new features without re-deriving them
each time. The full invariants live in [AGENTS.md](../../AGENTS.md);
this page is the rationale.

## Bet on macOS-native

Sojourn is **SwiftUI on macOS 26+ only**. No Electron, no cross-platform
abstraction, no plans for Linux or Windows.

Why:

- The audience is mainstream Mac developers. macOS-native is a feature,
  not a constraint.
- The hard parts of the product (`defaults import/export`, FDA, TCC,
  cfprefsd, Keychain, code signing, notarization, App Sandbox edges)
  are macOS-specific. There is no portable equivalent.
- No portability tax means the layout, animation, and OS integration
  can be first-class.
- Helling-the-Linux-companion is **explicitly out of scope** — see
  [decisions/0014-no-linux-no-helling-plugin.md](../decisions/0014-no-linux-no-helling-plugin.md).

## Single writer at a time

Sojourn enforces a **cooperative writer lock** via
`.sojourn/active.toml` ([decisions/0012-cooperative-writer-lock.md](../decisions/0012-cooperative-writer-lock.md)).

Two Macs cannot simultaneously push to the same data repo. The pull
side resolves any drift before the push side proceeds. No three-way
merge, no per-file timestamps, no auto-rebase. The user always sees a
diff and has to confirm.

This costs concurrent multi-Mac edits but buys clarity: every commit in
the data repo is exactly the state of one Mac at one moment.

See [explain/cooperative-locking.md](cooperative-locking.md) for the
full reasoning.

## IPC, not linking

Sojourn invokes `brew`, `chezmoi`, `git`, `gitleaks`, `age`, and
`defaults` as **separate processes** — argv in, JSON / TOML / exit code
out. No FFI. No embedding. No shared library.

This is the licensing firewall ([decisions/0001-ipc-not-linking.md](../decisions/0001-ipc-not-linking.md)).
It also keeps operational tools at arm's length so Sojourn can ship under
GPL-3.0-or-later without turning CLI wrappers into in-process dependencies.

It is also a robustness choice: each backend is a process boundary that
can fail, time out, or get cancelled without taking the whole app down.

See [explain/ipc-not-linking.md](ipc-not-linking.md) for the full
licensing argument.

## Prefer boring, documented Apple APIs

`@Observable` over TCA ([decisions/0005-no-tca.md](../decisions/0005-no-tca.md)).
`Process` over `SwiftShell`. `/usr/bin/git` over libgit2 ([decisions/0007-shell-out-to-git.md](../decisions/0007-shell-out-to-git.md)).
Signed `.pkg` install for Homebrew over `curl | bash`
([decisions/0008-no-curl-bash-for-brew.md](../decisions/0008-no-curl-bash-for-brew.md)).

Each was a real choice between a fashionable third-party option and the
documented OS surface. Each chose the OS surface because:

- Apple frameworks have a Stack Overflow corpus and Apple support
  channel; third-party Swift packages have an issue tracker.
- Apple frameworks rarely ship breaking changes between OS versions;
  third-party packages routinely do.
- Sojourn's project-shape is "macOS app the maintainer ships for
  decades", not "library reused widely".

## Snapshot before mutating

Every destructive operation writes a backup to
`~/Library/Application Support/Sojourn/backups/<ts>-<op>/` first, with
30-day retention. See [reference/cleanup.md](../reference/cleanup.md).

This is non-negotiable. `chezmoi apply --force`, `defaults import`,
`brew bundle install --cleanup`, `git pull --force`, and orphan trashing all
snapshot first. The cost is disk space on a developer machine; the benefit is
the user can always undo.

## No telemetry, no server

Sojourn does not phone home. Ever. There is no Sojourn-operated server.
GitHub Device Flow is opt-in and uses `client_id` only (no secrets
embedded).

The user's git remote is the only network surface. The OSV / GHSA daily
fetch is the only outbound API call, and it is anonymous.

See [explain/threat-model.md](threat-model.md) for the full posture.

## Loud over silent

When a destructive operation is about to happen — overwriting local
edits, importing prefs that will trigger app relaunch, bypassing the
cooldown gate, ignoring a high-confidence secret-scan finding — Sojourn
**makes the user read the consequence**. The `Commit anyway` button on
verified-provider gitleaks findings disables for 5 seconds. The pull
preview shows every diff. The conflict pane forces resolution before
push.

False confidence ages worse than an extra click.

## Ship 80% of the envisioned feature, then ship the next one

v0.4 continues the same discipline: reset the app to a quiet native macOS
utility before adding more backend scope. Sandboxed-app sync, richer conflict
resolution, and plugin-style manager expansion can wait until the core shipped
surfaces feel trustworthy.

The active plan is in [process/plans/v0.4-plan.md](../process/plans/v0.4-plan.md);
the deferred list is in [process/future.md](../process/future.md). Honest scope
cuts beat infinite-runway features.

## See also

- [AGENTS.md](../../AGENTS.md) — the full invariants and "do not do"
  list.
- [decisions/](../decisions/) — every architectural choice as an ADR.
- [explain/trade-offs.md](trade-offs.md) — what Sojourn doesn't do and
  why.
