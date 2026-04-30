# Open questions

Decisions deferred to the maintainer (audit §8 + the docs-rework
proposal §11). These block phases 12–14 progress and are listed here to
prevent each phase from blocking on them ad-hoc.

## Audit §8 — maintainer decisions

### 1. Native-cargo, native-mas timing

Both are cheap. Should they ship in v1 (proves the plugin protocol shape)
or v1.1 (saves bandwidth for harder gaps)? Current plan: phase 13.

### 2. Plugin trust model

cosign verification per plugin requires the user to manage a trust list.
Is the v1 plugin host:

- (a) signature-required
- (b) signature-optional-with-warning
- (c) unsigned-allowed?

Current plan: signature-required (per ADR-0013).

### 3. Default secret broker order

When both `op` and an age key are present, which does Sojourn prefer?
The audit recommends 1Password primary, age fallback (codified in
ADR-0011). Maintainer may prefer different default for homelab/single-user
case.

### 4. Discover pane scope

Live cfprefsd watcher inadvertently captures every preference change.
Pick:

- (a) opt-in-per-domain recording
- (b) global recording with redaction
- (c) something else

Current plan: blocked. No spec yet. Phase 12 cannot land §1.5 / §4.2.9 /
§4.2.10 features until decided.

### 5. History retention

`deletions.db` is 30d per design. Is push/pull history also 30d, longer,
or forever? Current plan: 30d (matches deletions). Phase 11 §3.1.6 lands
the SQLite history but retention policy is open.

### 6. Per-machine override format

chezmoi's `promptOnce` vs Sojourn's `.sojourn/machines/<id>.toml`. Audit
recommends the chezmoi-native path; maintainer may keep the Sojourn-side
metadata for fleet-management features that don't fit chezmoi's model.

### 7. OSV/GHSA fetch frequency and feed source

Daily refresh per
[reference/cooldown-policy.md](../reference/cooldown-policy.md).
Source: `api.osv.dev` only, or also GitHub Security Advisories direct?

### 8. Conflict shapes spec

[reference/conflict-shapes.md](../reference/conflict-shapes.md) enumerates
all six shapes (already shipped). Maintainer should sign off that the
list is complete. Audit §1.6 closed; this is a no-op confirmation.

## Docs-rework proposal §11 — naming decisions

All seven naming questions resolved in the Phase 7.5 docs-rework planning
session (2026-04-30). Maintainer chose strict proposal §3 naming. See
[Decided](#decided) for the full closeout.

## How to close a question

1. Decide. Document the decision (and reasoning) here.
2. If the decision is architectural, write a new ADR.
3. Update the relevant implementation-plan phase.
4. Strike the question from this file (move to a "Decided" section
   below).

## Decided

### Docs-rework proposal §11 — strict §3 naming (closed 2026-04-30, Phase 7.5)

Maintainer ratified strict proposal §3 naming for the docs tree. All
seven sub-questions resolved together; rename pass landed in Phase 7.5.

| § | Question | Decision | Rationale / record |
|---|---|---|---|
| 11.1 | `AGENTS.md` vs `CLAUDE.md` canonical | `AGENTS.md` is the canonical entry; `CLAUDE.md` retains the invariants list with cross-link from AGENTS.md | Helling-aligned; agent-agnostic; future-proof for Cursor / Codex / Aider |
| 11.2 | `start/` vs `tutorials/` | `start/` | URL brevity; "tutorials" reads like homework |
| 11.3 | `explain/` vs `explanation/` | `explain/` | URL brevity |
| 11.4 | ADR retention policy | Keep superseded ADRs inline with `Status: Superseded by NNNN` | Preserves historical reasoning; codified in `process/DOCS_POLICY.md` |
| 11.5 | Per-manager page depth | Full Sojourn-specific (mpm flags, JSON shape, tier, known-broken) | Single source of truth for AI agents + contributors |
| 11.6 | Spec docs vs reference docs | No separate `docs/spec/`; file formats + plugin protocol live in `reference/` | Tree shallow; readers don't care about spec-vs-reference distinction |
| 11.7 | Stub sunset version | `v0.3` for most stubs; `v0.4` for `ARCHITECTURE.md` (high inbound-link density); `n/a` for the root `THIRDPARTY.md` pointer | Codified in `process/DOCS_POLICY.md` |

#### Phase 7.5-driven additional decisions (same session)

Renames applied atomically in Phase 7.5; redirect stubs at every old path
sunset `v0.3`. Recorded in `docs/redirects.toml`.

| Old path | New path | Reason |
|---|---|---|
| `docs/reference/managers/` | `docs/reference/package-managers/` | Match proposal §3 vocabulary |
| `docs/reference/managers/README.md` | `docs/reference/package-managers/index.md` | Proposal §3 landing-file convention |
| `docs/reference/preference-domains.md` | `docs/reference/pref-domains.md` | Proposal §3 short-form |
| `docs/reference/bootstrap-flow.md` | `docs/explain/bootstrap-state-machine.md` | Reclassified reference → explain (rationale-heavy) |
| `docs/reference/observability.md` | `docs/explain/observability.md` | Reclassified reference → explain |
| `docs/explain/competitive-landscape.md` | `docs/explain/why-sojourn.md` | Scope-expanded from competitive matrix to wider framing |
| `docs/explain/future-work.md` | `docs/process/future.md` | Reclassified explain → process (deferred-work tracking is project process, not user-facing rationale) |
| `THIRDPARTY.md` (full content at root) | `docs/reference/third-party.md` (full); root keeps 1-line pointer | GH ecosystem keeps surfacing root file; canonical content lives in reference |

New file added: `docs/reference/chezmoi-features.md` — the
feature-surface index promised by audit §2.2.
