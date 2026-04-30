# Exclude a package from a specific Mac

## Goal

Prevent a package from installing on one Mac (e.g. exclude
`docker` from the work laptop where IT installs it via MDM).

## Prereqs

- A package in `packages.toml`.
- The Mac you want to exclude has its `machine_id` registered in
  `<data-repo>/.sojourn/machines/`.

## Steps

1. **Open the Packages pane** on the Mac you want to exclude.
2. Find the package, click *Exclude on this Mac*. Sojourn:
   - Reads the local `machine_id` (from `~/Library/Application Support/Sojourn/machine.toml`).
   - Adds an exclude entry to `packages.toml`:

     ```toml
     [per_machine.MAC-3F7A]
     brew_formulae_exclude = ["docker"]
     ```

3. **Save and push**.

## Effect

- On the excluded Mac, `mpm restore` skips `docker`.
- On other Macs, `docker` installs as usual.
- The exclude is honored on every future pull, not just the next one.

## Multi-package exclusions

```toml
[per_machine.MAC-3F7A]
brew_formulae_exclude = ["docker", "podman"]
cask_exclude = ["docker"]
npm_globals_exclude = ["pnpm"]
```

## Per-Mac additions

The same `[per_machine.<id>]` block also supports adds:

```toml
[per_machine.MAC-9C2B]
brew_formulae = ["asdf"]    # only on this Mac
mas = [{ id = "1320666476", name = "Wipr 2" }]
```

See [reference/file-formats/packages-toml.md](../../reference/file-formats/packages-toml.md)
for the full schema.

## Verification

- The excluded package is no longer installed on this Mac after
  apply.
- Other Macs install the package normally.
- `packages.toml` records the exclusion.

## Troubleshooting

- **"Exclude didn't take effect"** — the local Mac's `machine_id`
  in `packages.toml` must match the actual machine id at
  `~/Library/Application Support/Sojourn/machine.toml`. Verify in
  Settings → About → Machine ID.
- **"Want to exclude on most Macs, include on one"** — flip the
  schema: remove from base list and add only to the one Mac via
  `per_machine.<id>.brew_formulae`.

## See also

- [reference/file-formats/packages-toml.md](../../reference/file-formats/packages-toml.md).
- [reference/file-formats/machines-toml.md](../../reference/file-formats/machines-toml.md).
- [pin-version.md](pin-version.md).
