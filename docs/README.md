# Sojourn docs

This tree follows [Diátaxis](https://diataxis.fr) for the four reader modes,
with three Sojourn-specific siblings (`decisions/`, `process/`, `design/`) for
artifacts Diátaxis does not cover.

## Reader-mode quadrants

| Quadrant | Goal | Path |
|---|---|---|
| **Start** | Learn by doing | [start/](start/) |
| **How-to** | Solve a specific task | [how-to/](how-to/) |
| **Reference** | Look up exact facts | [reference/](reference/) |
| **Explain** | Understand the why | [explain/](explain/) |

## Sojourn-specific siblings

| Tree | Stability | Audience |
|---|---|---|
| [decisions/](decisions/) | Immutable ADRs | Contributors, maintainers |
| [process/](process/) | High churn | Contributors, maintainers |
| [design/](design/) | Release-cadence | Designers, maintainers |
| [assets/](assets/) | Per-doc | Docs build |

## Top-level entry points

### New users — start here

- [Tutorial 01 — Install Sojourn](start/01-install.md) — first install on a single Mac.
- [Tutorial 02 — Set up a new data repository](start/02-first-push.md) — first push.
- [Tutorial 03 — Onboard a second Mac](start/03-second-machine.md) — pull onto another Mac.
- [Tutorial 04 — Recover on a fresh Mac](start/04-recover-from-loss.md) — end-to-end recovery.

### Day-to-day tasks

- [How-to: packages](how-to/packages/) — pin versions, exclude per Mac, handle cooldowns, export SBOM.
- [How-to: dotfiles](how-to/dotfiles/) — templates, encryption, externals, SSH config, run-scripts.
- [How-to: sync](how-to/sync/) — resolve conflict, revert push, transfer writer lock, rotate age keys.
- [How-to: secrets](how-to/secrets/) — set up 1Password, customise gitleaks, handle a finding.
- [How-to: preferences](how-to/preferences/) — track an app, sandboxed apps, recover failed import.
- [How-to: diagnostics](how-to/diagnostics/) — export bundle, reset tool detection.

### Reference

- [Architecture](reference/architecture.md) — top-down system spec.
- [Modules](reference/modules.md) — per-module responsibilities.
- [Sync model](reference/sync-model.md) + [conflict shapes](reference/conflict-shapes.md).
- [Cooldown policy](reference/cooldown-policy.md) — tier ladder + advisory bypass.
- [Secret brokers](reference/secret-brokers.md) + [chezmoi features](reference/chezmoi-features.md).
- [Package managers](reference/package-managers/) — coverage matrix + 18 per-manager pages.
- [File formats](reference/file-formats/) — every TOML / SQLite shape Sojourn writes.
- [Settings](reference/settings.md), [keyboard shortcuts](reference/keyboard-shortcuts.md), [CLI placeholder](reference/cli.md).

### Understanding the design

- [Why Sojourn](explain/why-sojourn.md) — competitive landscape + framing.
- [Design philosophy](explain/design-philosophy.md) — macOS-native, single-writer, IPC-not-linking.
- [Trade-offs](explain/trade-offs.md) — what Sojourn deliberately doesn't do.
- [IPC, not linking](explain/ipc-not-linking.md) — the licensing firewall.
- [Tier model](explain/tier-model.md) — why 7-day cooldown.
- [Cooperative locking](explain/cooperative-locking.md) — why no three-way merge in v1.
- [Threat model](explain/threat-model.md) — adversaries, mitigations, scope.
- [Carry vs sync](explain/carry-vs-sync.md) — vocabulary.
- [Bootstrap state machine](explain/bootstrap-state-machine.md) + [observability](explain/observability.md).

### Maintainer / contributor

- [Decisions: ADR log](decisions/README.md) — 14 architectural decisions.
- [Process: audit](process/audit-2026-04.md) — gap analysis + coverage map.
- [Process: implementation plan](process/implementation-plan.md) — phased delivery (phases 0–14).
- [Process: open questions](process/open-questions.md) — deferred decisions.
- [Process: future](process/future.md) — long-tail backlog.
- [Process: docs policy](process/DOCS_POLICY.md) — redirect rules, ADR immutability, naming.
- [Process: doc style](process/doc-style.md) — voice, terminology, conventions.
- [Process: release checklist](process/release.md) — release-prep flow.
- [How-to: contribute development](how-to/development/) — add package manager / pref domain / write an ADR.

## Conventions

- File names: `kebab-case.md`.
- Headings: sentence case.
- Internal links: repo-relative paths.
- Mermaid first; PNG only when mermaid cannot represent.
- ADRs: `NNNN-kebab-case.md`, sequentially numbered, never reused, never reordered.

See [process/doc-style.md](process/doc-style.md) for the full style rules.
