# `machines.toml` schema

Per-Mac metadata for fleet management. Records each Mac that
participates in the sync, its identifier, hostname, and any
per-machine overrides referenced from `packages.toml`.

## Path

`<data-repo-root>/.sojourn/machines/<machine_id>.toml`. One file per
Mac. Tracked by git.

## Per-machine file shape

```toml
schema_version = "1"
machine_id     = "MAC-3F7A"
hostname       = "binghzals-MBP"
model          = "MacBook Pro (14-inch, M3 Pro, 2024)"
os             = "macOS 14.5 (23F79)"
sojourn_version = "0.1.3"
first_seen     = "2026-04-15T09:23:11Z"
last_seen      = "2026-04-30T14:02:11Z"

[overrides]
# inline notes about why this machine has overrides
note = "Work laptop. No personal apps; no Pixelmator."
```

## How `machine_id` is generated

`machine_id` is derived from the Mac's hardware UUID at first run:

```swift
let uuid = IORegistryEntryCreateCFProperty(...,  kIOPlatformUUIDKey ...)
let prefix = "MAC-"
let suffix = uuid.prefix(4).uppercased()  // first 4 hex
return "\(prefix)\(suffix)"
```

Collision risk on 4-hex is ~1 in 65k. On collision the user is
prompted to extend the suffix to 8 hex. The `machine_id` is opaque to
the user but visible in the Machines pane.

## Why this format (not chezmoi `promptOnce`)

Decided in
[decisions/0017-keep-machines-toml-fleet-metadata.md](../../decisions/0017-keep-machines-toml-fleet-metadata.md)
(closes audit §2.2.9 +
[process/open-questions.md](../../process/open-questions.md) §6).

`promptOnce` is a chezmoi-state-cached prompt; the value lives **locally**
on each Mac, isn't tracked, isn't fleet-visible. `.sojourn/machines/<id>.toml`
lives **in the data repo** (git-tracked) and powers Sojourn surfaces that
require cross-machine visibility:

- Machines pane (audit §4.1) — fleet list with hostname, model,
  last-seen timestamp, age recipient, `last-push` SHA per Mac.
- Per-machine package overrides
  ([reference/sync-model.md](../sync-model.md))
  — `[brew.only."work-mbp"]` / `[brew.exclude."personal-mini"]`
  reference the `machine_id` defined here.
- Refuse-push-on-mismatch validation (see "Format constraints" below).
- Fresh-Mac onboarding context — new Mac pulls the repo and
  immediately knows the rest of the fleet.

`promptOnce` does none of that, so migrating would delete the
Machines-pane data model. Sojourn keeps `.sojourn/machines/<id>.toml`
for fleet metadata + per-machine package overrides, and **also**
supports `promptOnce` inside chezmoi templates for genuinely-local
template values that don't belong in fleet metadata (per-machine API
endpoints, per-machine local paths, interactive first-run prompts).

Both formats coexist; they solve different problems. The how-to in
`docs/how-to/dotfiles/per-machine-values.md` documents which to reach for.

## Format constraints

- TOML 1.0.
- One file per Mac under `.sojourn/machines/`.
- File name is `<machine_id>.toml`.
- Sojourn refuses to push if the file's `machine_id` ≠ the local Mac's
  derivation.

## See also

- [packages-toml.md](packages-toml.md) — `[per_machine.<id>]`
  references this file's `machine_id`.
- [active-toml.md](active-toml.md) — the writer-lock file uses
  `machine_id` to identify the active writer.
- [reference/backends/chezmoi.md](../backends/chezmoi.md) —
  `promptOnce` mechanism that coexists for local-only template values.
- [decisions/0017-keep-machines-toml-fleet-metadata.md](../../decisions/0017-keep-machines-toml-fleet-metadata.md)
  — the decision record.
- [process/open-questions.md](../../process/open-questions.md) §6 —
  closeout.
