# Pin a package version

## Goal

Lock a specific version of a package across Macs so an upgrade doesn't
break your setup.

## Prereqs

- The package is already tracked in `packages.toml`.
- The package manager supports version pinning (brew formulae, pip,
  npm, cargo, gem). Casks have weaker pinning semantics; see below.

## Steps

1. **Open the Packages pane** → find the package.
2. Click *Pin version*. Sojourn shows a version-picker dropdown
   populated from the manager's available versions.
3. **Select** the version you want pinned. Sojourn rewrites the entry
   in `packages.toml`:

   For a brew formula:
   ```toml
   [brew]
   formulae = [
     { name = "node@22", version = "22.5.1", reason = "transitive consumer breaks on 22.6" },
   ]
   ```

   For a cask:
   ```toml
   [cask]
   casks = [
     { name = "rectangle", version = "0.79", reason = "split-screen regression in 0.80" },
   ]
   ```

4. **Save** — Sojourn re-runs `mpm restore --pin` (where supported)
   to verify the version exists.
5. **Push**.

## Cask version pinning

Casks are tricky. Homebrew's cask system explicitly does not support
version-pinning the way formulae do. Sojourn handles cask pins by:

- Recording the version in `packages.toml`.
- On `mpm restore`, downloading the specific `.dmg`/`.pkg` from the
  cask's `version` block if the URL contains the version.
- If the upstream cask only ships "current" (no versioned URL),
  Sojourn warns the user that the pin is best-effort.

Some casks (`docker`, `1password`, `chrome`) update themselves outside
Homebrew. In those cases, the pin is meaningless. Audit §2.4 covers
this distinction further.

## Verification

- `packages.toml` records the version.
- `brew list --versions <name>` (or equivalent) shows the pinned
  version.
- A peer Mac that pulls and applies installs exactly the same
  version.

## Troubleshooting

- **"Version not in dropdown"** — older versions get pruned from
  upstream registries. Type the version manually if you know it
  exists in the manager's archive.
- **"Pin doesn't survive `brew upgrade`"** — `brew upgrade` ignores
  cask pins and respects formula pins only when set via `brew pin`.
  Sojourn's pin is enforced through `mpm restore` only; manual
  `brew upgrade` from the user circumvents Sojourn.

## See also

- [reference/file-formats/packages-toml.md](../../reference/file-formats/packages-toml.md)
  — full schema.
- [reference/cooldown-policy.md](../../reference/cooldown-policy.md)
  — cooldown vs pin interaction.
- [exclude-per-machine.md](exclude-per-machine.md) — when to use
  per-machine override instead of pin.
