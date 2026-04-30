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

## Open question — chezmoi-native migration

[`process/open-questions.md`](../../process/open-questions.md) §6
flags this file as a candidate for migration to chezmoi's native
`promptOnce` / `promptStringOnce` / `promptBoolOnce` mechanism. v1
ships the Sojourn-side TOML; v1.x may collapse into chezmoi state if
the maintainer decides the chezmoi-native path beats Sojourn-side
metadata.

If migration happens:

- Per-machine overrides move into chezmoi `.chezmoi.yaml` `data`
  blocks.
- `machines.toml` files become chezmoi-state-cached prompts.
- Bootstrap on a fresh Mac without Sojourn still works (plain
  `chezmoi init` re-prompts).

The v1 TOML approach is simpler today; the chezmoi-native path is
better for fleet-management UX once the friction is justified.

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
  `promptOnce` mechanism that may replace this file in v1.x.
- [process/open-questions.md](../../process/open-questions.md) §6 —
  chezmoi-native migration question.
