# Open questions

Decisions deferred to the maintainer (audit §8 + the docs-rework
proposal §11). These block phases 12–14 progress and are listed here to
prevent each phase from blocking on them ad-hoc.

## Audit §8 — maintainer decisions

All eight audit §8 questions resolved on 2026-04-30. See
[Decided](#decided) for closeout. Phase 12 / 13 / 14 unblocked.

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

### Audit §8 — eight questions (closed 2026-04-30)

Maintainer reviewed each question against the audit, the relevant ADRs,
and the v1 → v1.x phase plan. Closures below; ADRs cited where the
decision is architectural.

#### 1. Native-cargo, native-mas timing — defer cargo; mas opportunistic in Phase 13

Native cargo does **not** prove the plugin protocol. Native services
conform to `PackageBackend` (Phase 10), which is in-process Swift.
The plugin protocol is JSON-RPC over stdio for out-of-process executables
(ADR-0013). They are different protocols. The plugin protocol is
validated by the `mise` reference plugin in Phase 14 per
[reference/plugin-protocol.md](../reference/plugin-protocol.md).

- **Cargo: dropped from native scope.** `MPMService` continues to handle
  cargo (audit §2.3 marks this a wash). Re-evaluated for v1.x if
  dotfile-classification of `~/.cargo/config.toml` proves insufficient.
- **mas: opportunistic in Phase 13.** ~80 LOC; ships when `BrewService`
  is ready, not as a separate milestone.
- **brew + cask: ship in Phase 13 as planned.** These are the
  load-bearing native swaps (audit §2.3; 80%+ of installed packages,
  unlocks taps + services + Brewfile interop).

Implementation-plan Phase 13 wording updated to drop the
"prove the plugin protocol" justification.

#### 2. Plugin trust model — signature-required, keyless Sigstore by default

v1 plugin host is **signature-required**. Verification uses **keyless
Sigstore identities** (Fulcio cert-identity + cert-oidc-issuer) by
default; static-key fallback for offline / private plugins. Recorded in
[ADR-0015](../decisions/0015-keyless-cosign-plugin-trust.md).

The audit's Q2 framing assumed `cosign sign-blob --key`-style signing
with a per-plugin static `public_key` in `manifest.toml`. That is the
pre-Cosign-v3 model. Cosign v3.0+ defaults to keyless signing via Fulcio

- Rekor; signatures bind to an OIDC identity (e.g.
  `github.com/sojourn-plugins/mise/.github/workflows/release.yml`) and
  land in a public transparency log. Sojourn adopts this default.

Per-plugin override stays as designed (Settings → Plugins → "Allow
unsigned" with red banner).

[reference/plugin-protocol.md](../reference/plugin-protocol.md) manifest
schema updated.

#### 3. Default secret broker order — 1Password primary with cache + timeout, Keychain promoted, Bitwarden deferred

Detection ladder revised per
[ADR-0016](../decisions/0016-secret-broker-order-and-cache.md):

1. **1Password** (`op` CLI) — primary, **with** a per-secret last-success
   cache in Keychain and a configurable `secret_broker.read_timeout_seconds`
   (default 5s). On `op` timeout/outage, fall back to cached value with a
   visible "1Password unreachable" banner. Fail-closed only if no cache
   exists.
2. **macOS Keychain** (`keyring` chezmoi func) — secondary. Always
   present, no network, no session timeout. Promoted from tertiary in
   ADR-0011.
3. **age** — fallback.
4. **Bitwarden** — deferred to v1.1. Strictly worse than Keychain on
   every dimension that matters in the apply hot-path (network, session
   timeout, extra CLI install).
5. **plaintext** — refused unless user explicitly waives.

ADR-0011 stays valid; ADR-0016 supplements with the order, cache, and
timeout that the maintainer needed to land before Phase 14 promotes 0011.

#### 4. Discover pane scope — record-session mode, deferred to v1.1

cfprefsd-as-always-on watcher rejected. The audit's three options
(opt-in-per-domain / global-with-redaction / something-else) reduce to
"something else": **record-session mode**, specified in
[explain/discover-pane.md](../explain/discover-pane.md).

User clicks Start recording → Sojourn snapshots whitelisted preference
domains → user makes the changes they want to capture → user clicks Stop
→ Sojourn shows a structured diff → user picks which keys to commit.

Bounded in time, bounded in domain scope, no live cfprefsd watcher, no
"redaction" hand-wave. Ships v1.1; v1 omits Discover entirely (Track-app
pane covers the explicit-track case).

Phase 12 §1.5 / §4.2.9 / §4.2.10 stay deferred to v1.1 with the spec
above as the gating dependency. Phase 12 unblocked for the rest of its
deliverables.

#### 5. History retention — 365d for `jobs`, 90d for `job_logs`

`deletions.db` 30d retention is a recoverability window (matches Trash).
`history.db` is forensic data. The two databases solve different
problems and shouldn't share retention. xz precedent (CVE-2024-3094,
~24-month maintainer-infiltration ramp) shows you can need to look back
12–24 months to trace a malicious install.

- `jobs` rows: **365 days**. Cost is trivial (~700KB/year at 5 ops/day).
- `job_logs` rows: **90 days**. Heavier; capped further by
  `history.max_log_lines_per_job = 10000`.
- New backstop: `history.max_db_size_mb = 500` with oldest-first eviction.

[reference/file-formats/history-db.md](../reference/file-formats/history-db.md)
"Retention" section and [reference/settings.md](../reference/settings.md)
defaults updated.

Side effect: `diagnostics.bundle_includes_history_db = true` default now
actually carries useful history. 30-day retention made exported bundles
near-useless for week-old bug reports.

#### 6. Per-machine override format — keep `.sojourn/machines/<id>.toml`

`promptOnce` is a chezmoi-state-cached prompt; the value lives locally
on each Mac, isn't tracked, isn't fleet-visible. That's the wrong shape
for Sojourn's Machines pane, fleet ops, and `machine_id` validation
(refuse-push-on-mismatch in
[reference/file-formats/machines-toml.md](../reference/file-formats/machines-toml.md)).
The audit's recommendation to migrate would delete the Machines-pane
data model.

**Keep `.sojourn/machines/<id>.toml`** for fleet metadata + per-machine
package overrides. **Coexist** with `promptOnce` for genuinely-local
template values that don't belong in fleet metadata (per-machine API
endpoints, per-machine paths). They solve different problems.

Recorded in
[ADR-0017](../decisions/0017-keep-machines-toml-fleet-metadata.md).
machines-toml.md "Open question" section rewritten as "Why we keep this
format."

#### 7. OSV/GHSA fetch frequency and feed source — OSV.dev only, 6-hourly, delta-fetch

The audit's framing ("`api.osv.dev` only, or also GHSA direct?") implies
two separate sources. They aren't. GHSA is **already** an upstream source
for OSV.dev — `github.com/github/advisory-database` publishes GHSA records
in OSV format and OSV.dev imports them continuously. "OSV.dev only"
already covers GHSA. GHSA-direct adds nothing in coverage; only marginal
freshness (sub-hour import lag), which is in the noise at any sensible
refresh cadence.

Decisions:

- **Source: OSV.dev only.**
- **Frequency: every 6 hours (4× per day), not daily.** Daily refresh
  has worst-case 24h staleness, undermining the OSV-bypass promise
  (tier-model.md: "you will never sit on a known-vulnerable package
  because of a cooldown rule"). The 2024–2026 incident-window data shows
  2–8h disclosure-to-detection windows. 6-hourly cuts worst-case to ~6h
  while staying inside `api.osv.dev` rate limits and `NSBackgroundActivityScheduler`
  budgets.
- **Mechanism: per-ecosystem `modified_id.csv` delta-fetch.** Cost drops
  from O(installed-packages) per refresh (200+ POSTs) to O(new-vulns-since-last-fetch)
  (typically <10).

[reference/cooldown-policy.md](../reference/cooldown-policy.md) updated.
New setting `network.osv_modified_id_base_url`; renamed
`sync.background_refresh_interval_hours` split into `mpm.outdated_refresh_hours`
(1) and `network.osv_refresh_interval_hours` (6).

#### 8. Conflict shapes spec — two new shapes, one wrong claim, shape-4 split

Not a no-op confirmation; the doc had defects.

- **New shape 7: encrypted file conflict.** `encrypted_*.age`
  divergence between Macs without a shared recipient key. Resolution UX
  is fundamentally different — can't show the user a content diff
  without the key. Either abort with "compare on a machine with both
  keys" or ciphertext-only commit-timestamp diff.
- **New shape 8: secret-broker reference vs. inline value.** Template
  form (`{{ onepasswordRead "op://..." }}`) vs. plaintext (e.g. from a
  broker outage or manual edit). Auto-resolve to template; do not prompt.
- **Shape 4 split** into 4a (file-level divergence, auto-merge attempt)
  and 4b (same-key divergence, keyed-diff UX). Same shape, different
  resolution path.
- **Multi-way merge claim corrected.** The doc said "second-to-arrive
  sees one merge at a time" — git doesn't serialize by arrival.
  Cooperative writer lock catches the 95% case; multi-way past the lock
  is rejected and the user picks a winner manually.

[reference/conflict-shapes.md](../reference/conflict-shapes.md) updated.

### Docs-rework proposal §11 — strict §3 naming (closed 2026-04-30, Phase 7.5)

Maintainer ratified strict proposal §3 naming for the docs tree. All
seven sub-questions resolved together; rename pass landed in Phase 7.5.

| §    | Question                             | Decision                                                                                                                    | Rationale / record                                                       |
| ---- | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| 11.1 | `AGENTS.md` vs `CLAUDE.md` canonical | `AGENTS.md` is the canonical entry; `CLAUDE.md` retains the invariants list with cross-link from AGENTS.md                  | Helling-aligned; agent-agnostic; future-proof for Cursor / Codex / Aider |
| 11.2 | `start/` vs `tutorials/`             | `start/`                                                                                                                    | URL brevity; "tutorials" reads like homework                             |
| 11.3 | `explain/` vs `explanation/`         | `explain/`                                                                                                                  | URL brevity                                                              |
| 11.4 | ADR retention policy                 | Keep superseded ADRs inline with `Status: Superseded by NNNN`                                                               | Preserves historical reasoning; codified in `process/DOCS_POLICY.md`     |
| 11.5 | Per-manager page depth               | Full Sojourn-specific (mpm flags, JSON shape, tier, known-broken)                                                           | Single source of truth for AI agents + contributors                      |
| 11.6 | Spec docs vs reference docs          | No separate `docs/spec/`; file formats + plugin protocol live in `reference/`                                               | Tree shallow; readers don't care about spec-vs-reference distinction     |
| 11.7 | Stub sunset version                  | `v0.3` for most stubs; `v0.4` for `ARCHITECTURE.md` (high inbound-link density); `n/a` for the root `THIRDPARTY.md` pointer | Codified in `process/DOCS_POLICY.md`                                     |

#### Phase 7.5-driven additional decisions (same session)

Renames applied atomically in Phase 7.5; redirect stubs at every old path
sunset `v0.3`. Recorded in `docs/redirects.toml`.

| Old path                                | New path                                                          | Reason                                                                                                |
| --------------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `docs/reference/managers/`              | `docs/reference/package-managers/`                                | Match proposal §3 vocabulary                                                                          |
| `docs/reference/managers/README.md`     | `docs/reference/package-managers/index.md`                        | Proposal §3 landing-file convention                                                                   |
| `docs/reference/preference-domains.md`  | `docs/reference/pref-domains.md`                                  | Proposal §3 short-form                                                                                |
| `docs/reference/bootstrap-flow.md`      | `docs/explain/bootstrap-state-machine.md`                         | Reclassified reference → explain (rationale-heavy)                                                    |
| `docs/reference/observability.md`       | `docs/explain/observability.md`                                   | Reclassified reference → explain                                                                      |
| `docs/explain/competitive-landscape.md` | `docs/explain/why-sojourn.md`                                     | Scope-expanded from competitive matrix to wider framing                                               |
| `docs/explain/future-work.md`           | `docs/process/future.md`                                          | Reclassified explain → process (deferred-work tracking is project process, not user-facing rationale) |
| `THIRDPARTY.md` (full content at root)  | `docs/reference/third-party.md` (full); root keeps 1-line pointer | GH ecosystem keeps surfacing root file; canonical content lives in reference                          |

New file added: `docs/reference/chezmoi-features.md` — the
feature-surface index promised by audit §2.2.
