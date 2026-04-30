# mpm — meta-package-manager

mpm v6.3.0+, Python-based, PyInstaller-frozen standalone binary available.
[https://github.com/kdeldycke/meta-package-manager](https://github.com/kdeldycke/meta-package-manager).
GPL-2.0-only — invoked as a subprocess only, never linked. See
[decisions/0001-ipc-not-linking.md](../../decisions/0001-ipc-not-linking.md).

> **Audit driver**: closes [process/audit-2026-04.md §1.4](../../process/audit-2026-04.md#1-doc-level-inconsistencies) (`--table-format json` is the mpm 6.x flag) + drives [§2.1](../../process/audit-2026-04.md#21-mpm-features-not-used) (sbom / PURL / sync / cleanup / locate / TOML snapshot wiring in implementation-plan Phase 12).

## Invocation contract

mpm 6.x renamed its output flag from `--output-format` back to
`--table-format`. **Pin to 6.x and use `--table-format json`.**

## Subcommands actually usable

- `mpm --table-format json installed` — returns `{manager_id: {errors[], id,
  name, packages: [{id, installed_version, name|null}]}}`. `name` is
  frequently `null` (pip, vscode). Always fall back to `id` for display.
- `mpm --table-format json outdated` — same shape with `latest_version`
  added. Per-manager `errors[]` is the partial-failure channel; surface it
  in the UI rather than failing the whole operation.
- `mpm --table-format json search <q>` — same per-manager shape. `pip` does
  not implement search, so its errors array fires on every cross-manager
  search — this is normal.
- `mpm --table-format json managers` — manager inventory with CLI path,
  version, platform compatibility.
- `mpm backup [FILE]` — **outputs TOML, not JSON**. Brewfile-style. Sojourn's
  snapshot format _is_ this file, committed into the repo as `packages.toml`.
- `mpm restore <FILE.toml>` — imperative, no JSON output.

## Latency budget

`mpm outdated` is unbounded. Dominant cost is brew's JSON API auto-refresh
(default was 1 day, **PR #21262 bumped to 7 days**, merged Dec 2025).

- Warm caches: 20s across all managers.
- Cold: 3+ minutes.
- mpm's own `-t/--timeout` default is 10 minutes per CLI call — too long
  for UX. Override with **90s per call**.

## Parallelization

mpm invokes managers sequentially in-process. Sojourn fans out per-manager
calls (`mpm --brew outdated`, `mpm --cask outdated`, …) in parallel from the
Swift layer and aggregates. Each fires its own `Job` with a spinner; partial
results stream.

## Supported managers on macOS (2026)

Reliable: brew, cask, mas, pip, pipx, npm, gem, composer, cargo, yarn,
vscode, uvx. **pnpm is not supported**; shell out directly or file a PR.
cargo has no native outdated; use `cargo install --list` for installed only.

## Installation strategy

Prefer `brew install meta-package-manager` when brew is present; fall back
to the **pre-built Nuitka-compiled standalone binaries**
(`mpm-macos-arm64.bin`) from GitHub releases. Do not bundle mpm inside
`Contents/Resources/` — it updates more often than Sojourn, and shipping a
frozen Python interpreter inside the app complicates notarization.

See [explain/bootstrap-state-machine.md](../../explain/bootstrap-state-machine.md) for the install state
machine.

## Risk

Single-maintainer project. README explicitly: *"maintained by only one
person."* Mitigation: keep the integration thin; any subcommand could in
principle be reimplemented against the underlying managers directly.
Preserve that option.
