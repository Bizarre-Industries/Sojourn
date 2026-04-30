# `packages.toml` schema

The canonical package list for a Sojourn-managed data repo. Generated
by `mpm backup` on push, consumed by `mpm restore` on pull. Sojourn
augments the mpm-native shape with per-machine override syntax for
fleet management.

## Path

`<data-repo-root>/packages.toml`. Tracked by git, committed on every
push that changes installed-package state.

## Top-level shape (v1)

```toml
schema_version = "1"

[brew]
formulae = [
  "git",
  "ripgrep",
  "node@22",
]

[cask]
casks = [
  "1password",
  "visual-studio-code",
  { name = "rectangle", version = "0.79", reason = "newer breaks split-screen" },
]

[mas]
apps = [
  { id = "1289583905", name = "Pixelmator Pro" },
]

[npm]
globals = [
  "pnpm",
  "typescript",
]

[pip]
globals = ["awscli"]

[pipx]
apps = ["poetry", "ruff"]

[cargo]
crates = ["just", "fd-find"]

[gem]
gems = ["rubocop"]

# ... one section per supported manager
```

The bare-string form is shorthand for a record with only `name`
populated. The record form supports per-package metadata (version
pin, reason, comment).

## Per-machine overrides

Sojourn extends mpm's flat list with a `[per_machine]` table keyed by
`machine_id`. Use this for casks/packages that should only install on
specific machines.

```toml
[per_machine.MAC-3F7A]
brew_formulae = ["asdf"]
cask = ["docker"]

[per_machine.MAC-9C2B]
brew_formulae_exclude = ["docker-compose"]
mas = [{ id = "1320666476", name = "Wipr 2" }]
```

`per_machine.<id>` declarations are merged into the base list at
restore time. `<key>_exclude` removes from the base. `machine_id`
strings come from `machines.toml` (see
[machines-toml.md](machines-toml.md)).

## PURL specifiers (audit §2.1.2; future)

Audit §2.1.2 calls for using PURL (Package URL) specifiers like
`pkg:npm/left-pad` instead of bare names where disambiguation is
needed. Phase 12 implements:

```toml
[npm]
globals = [
  "pkg:npm/typescript@5.5.0",
  "pkg:npm/@my-org/cli-tool",
]
```

PURLs disambiguate same-named packages across managers (e.g. `pip`
`requests` vs `npm` `requests`) and align with the SBOM that mpm 5.18+
emits via `mpm sbom --cyclonedx`.

## Format constraints

- TOML 1.0 spec. Sojourn's writer is `SojournFileCodec`
  (handwritten, deterministic — same key order on every push).
- UTF-8. No BOM.
- Trailing newline. No CRLF.
- Sorted keys per section (lexicographic).
- Two-space indentation in arrays-of-tables for readability.
- Comments preserved if present (Sojourn does **not** roundtrip
  comments in v1 — they survive only if the user edits manually).

## Validation

`SyncCoordinator` validates on read:

- `schema_version` must be `"1"`. Older / newer versions trigger
  migration or refusal. See
  [version-toml.md](version-toml.md).
- Manager sections that don't appear in the user's installed managers
  are warnings, not errors.
- Per-machine entries referencing unknown `machine_id` are warnings.
- Cask entries with `version` pinned but the cask doesn't support
  pinning trigger a UI prompt before restore.

## Backup format

`mpm backup` writes TOML directly. Sojourn's pre-op snapshot
(`~/Library/Application Support/Sojourn/backups/<ts>-<op>/packages.toml`)
is a verbatim copy of the previous state.

## See also

- [reference/backends/mpm.md](../backends/mpm.md) — `mpm backup` /
  `mpm restore` invocation surface.
- [machines-toml.md](machines-toml.md) — `machine_id` source.
- [version-toml.md](version-toml.md) — schema-version pinning.
- [reference/sync-model.md](../sync-model.md) — when Sojourn writes
  `packages.toml`.
- [process/audit-2026-04.md §2.1.1](../../process/audit-2026-04.md#21-mpm-features-not-used)
  — SBOM cross-reference.
