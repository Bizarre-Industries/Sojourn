# AGENTS.md

Entry point for AI agents and contributors. Helling-style minimal —
points at the canonical sources rather than duplicating them.

## Read first

1. [CLAUDE.md](CLAUDE.md) — the full invariants and "do not do" list.
   Applies to humans, Claude, Cursor, Codex, Aider, anyone editing the
   repo.
2. [docs/reference/architecture.md](docs/reference/architecture.md) —
   top-down system spec.
3. [docs/decisions/](docs/decisions/) — 14 ADRs covering load-bearing
   decisions (license, IPC-not-linking, no-symlink-prefs, cooldown,
   plugin protocol, etc.).
4. [docs/process/audit-2026-04.md](docs/process/audit-2026-04.md) —
   the active gap analysis driving v1 → v1.x.
5. [docs/process/implementation-plan.md](docs/process/implementation-plan.md)
   — phased delivery sequence (phases 0–14).

## When in doubt

- **Architectural change** → write a new ADR under
  [docs/decisions/](docs/decisions/) before merging.
- **New doc** → see
  [docs/process/DOCS_POLICY.md](docs/process/DOCS_POLICY.md) for
  quadrant placement, naming, and stub policy.
- **Adding a package manager** →
  [docs/how-to/development/add-package-manager.md](docs/how-to/development/add-package-manager.md).
- **Open question / deferred decision** →
  [docs/process/open-questions.md](docs/process/open-questions.md).

## Don't

- Edit a `decisions/NNNN-*.md` ADR after it's `Accepted`. Supersede via
  a new ADR.
- Add a new flat `.md` under `docs/` — every doc lives in a Diátaxis
  quadrant or one of the three siblings (`decisions/`, `process/`,
  `design/`).
- Bypass the "do not do" list in [CLAUDE.md](CLAUDE.md). It captures
  invariants like IPC-not-linking, no-TCA, no-libgit2, no-symlink-prefs
  — every one is backed by an ADR.

## Why a separate AGENTS.md

[Helling](https://github.com/Bizarre-Industries/Helling) (the
maintainer's other project) uses `AGENTS.md` as its canonical entry
point. Sojourn adopts the convention so any agent (Claude, Cursor,
Codex, Aider, future) lands here rather than guessing at filenames.

The full invariants live in [CLAUDE.md](CLAUDE.md) for now. Whether to
flip the canonical from CLAUDE.md to AGENTS.md is tracked as an open
question — see
[docs/process/open-questions.md](docs/process/open-questions.md)
"Docs-rework proposal §11 — naming decisions" Q1.
