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

These are docs-restructure decisions; the plan adopted defaults but
maintainer can override.

### 1. AGENTS.md vs CLAUDE.md

Default: AGENTS.md is canonical; CLAUDE.md becomes thin pointer.
Lands in Phase 7.

### 2. start/ vs tutorials/

Default: `start/` (URL brevity).

### 3. explain/ vs explanation/

Default: `explain/` (URL brevity).

### 4. ADR retention

Default: keep superseded ADRs inline with status=superseded. Codified in
[DOCS_POLICY.md](DOCS_POLICY.md).

### 5. Per-manager page depth

Default: full Sojourn-specific (mpm flags passed, JSON shape, tier,
known broken). Already shipped in Phase 5.

### 6. Spec docs vs reference docs

Default: no separate `docs/spec/`. File formats, plugin protocol live in
`reference/`.

### 7. Stub sunset version

Default: v0.3 for most stubs; v0.4 for ARCHITECTURE.md (high inbound link
density). Codified in [DOCS_POLICY.md](DOCS_POLICY.md).

## How to close a question

1. Decide. Document the decision (and reasoning) here.
2. If the decision is architectural, write a new ADR.
3. Update the relevant implementation-plan phase.
4. Strike the question from this file (move to a "Decided" section
   below).

## Decided

(Empty until a question is closed.)
