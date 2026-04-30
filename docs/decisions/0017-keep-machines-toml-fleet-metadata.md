# 0017 — Keep `.sojourn/machines/<id>.toml` for fleet metadata; coexist with chezmoi `promptOnce`

- **Status**: Accepted
- **Date**: 2026-04-30
- **Deciders**: Sojourn maintainer

## Context

Audit §2.2.9 + §8 Q6
([process/open-questions.md](../process/open-questions.md))
proposed migrating Sojourn's per-machine override store from
`.sojourn/machines/<id>.toml` to chezmoi's native `promptOnce` /
`promptStringOnce` / `promptBoolOnce` functions. The argument: chezmoi
already does this; a fresh Mac without Sojourn could still bootstrap via
plain `chezmoi init`.

The argument fails on shape, not on chezmoi-purity. `promptOnce` is a
**prompt-cache mechanism**: the value lives in chezmoi's local state DB on
each machine. It isn't tracked, isn't versioned, isn't fleet-visible.
`.sojourn/machines/<id>.toml` lives in the data repo (git-tracked) and
powers Sojourn surfaces that depend on cross-machine visibility:

- Machines pane (audit §4.1) — fleet list with hostname, model, last-seen
  timestamp, age recipient, `last-push` SHA per Mac.
- Per-machine package overrides
  ([reference/sync-model.md](../reference/sync-model.md))
  — `[brew.only."work-mbp"]` / `[brew.exclude."personal-mini"]` reference
  the `machine_id` defined in this file.
- Refuse-push-on-mismatch validation
  ([reference/file-formats/machines-toml.md](../reference/file-formats/machines-toml.md))
  — Sojourn cross-checks `machine_id` against the local Mac's hardware
  UUID at push time.
- Fresh-Mac onboarding context — new Mac pulls the repo and immediately
  knows the rest of the fleet.

`promptOnce` does none of this. Migrating would delete the Machines-pane
data model.

## Decision

Sojourn keeps `.sojourn/machines/<id>.toml` as the canonical store for
**fleet metadata + per-machine package overrides**. chezmoi `promptOnce`
is **supported in parallel** for genuinely-local template values that
don't belong in fleet metadata — e.g. a per-machine API endpoint inside
`~/.config/foo/config.toml`, a per-machine local path, an interactive
first-run prompt for a value the user wants chezmoi-cached on first apply.

Both formats coexist; they solve different problems. A how-to in
`docs/how-to/dotfiles/per-machine-values.md` documents which to reach for.

## Consequences

### Positive

- Machines pane keeps working as designed.
- Fleet ops (refuse-push-on-mismatch, last-seen, age recipient list)
  keep working.
- Power users who want the chezmoi-native path for their own templates
  still have it; Sojourn doesn't fight the tool.

### Negative

- Two formats for "per-machine config" — contributor-onboarding cost in
  knowing which to use when. Mitigated by the how-to and by clear
  domain separation (fleet metadata vs. template values).
- A fresh Mac without Sojourn cannot fully reconstruct the fleet view
  via plain `chezmoi init`. This was the audit's main objection;
  Sojourn accepts it because the Machines pane is a Sojourn-specific
  feature, not a chezmoi feature.

### Neutral

- machines-toml.md's "Open question — chezmoi-native migration" section
  rewritten as "Why we keep this format" and points here.
- ADR retention policy ([process/DOCS_POLICY.md](../process/DOCS_POLICY.md))
  preserves this decision in-line with the inverse argument's reasoning
  for future maintainers.

## Alternatives considered

- **Migrate to `promptOnce`** (audit recommendation) — rejected. Deletes
  the Machines-pane data model in service of chezmoi-purity that
  Sojourn's audience doesn't ask for.
- **Drop `promptOnce` support entirely** — rejected. Power users have
  legitimate template-value-prompt cases that don't belong in fleet
  metadata; refusing to support `promptOnce` makes Sojourn fight chezmoi.
- **Wrap `promptOnce` in Sojourn's UI and store the cached value in
  `.sojourn/machines/<id>.toml`** — rejected. Adds a Sojourn-side proxy
  for a chezmoi-native feature; complexity without payoff.
