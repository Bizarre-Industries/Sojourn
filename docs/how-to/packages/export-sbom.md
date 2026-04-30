# Export an SBOM

## Goal

Generate a CycloneDX or SPDX Software Bill of Materials for the
package state in your data repo. Useful for compliance reporting,
license auditing, and cross-referencing with OSV advisories.

## Prereqs

- mpm v5.18+ (for `mpm sbom`).
- A populated `packages.toml`.

## Steps

1. **Open Sojourn → Packages pane → SBOM**.
2. Pick a format:
   - **CycloneDX 1.5** (recommended — pairs with OSV / GHSA feeds)
   - **SPDX 2.3** (audit-pipeline standard)
3. Pick a destination:
   - *Save next to `packages.toml`* — commits an
     `sbom.cyclonedx.json` (or `.spdx.json`) into the data repo.
   - *Save to disk* — pick an arbitrary path.
4. **Generate**. Sojourn invokes:

   ```sh
   mpm sbom --cyclonedx > sbom.cyclonedx.json
   ```

   Or `--spdx` for SPDX. The output includes every package with name,
   version, manager, license (where the manager exposes it).

## Auto-export on every push (Phase 12)

Phase 12 adds a *Settings → Sync → Auto-export SBOM* toggle. When on,
Sojourn writes `sbom.cyclonedx.json` next to `packages.toml` on
every push. The SBOM is git-tracked, so the History pane gives you
a per-commit history of installed packages.

## Verification

- `sbom.cyclonedx.json` exists at the chosen path.
- The file validates against the CycloneDX 1.5 JSON schema (e.g.
  via `cyclonedx-cli validate --input-file sbom.cyclonedx.json`).
- Cross-referencing with OSV produces no advisories for currently
  installed versions.

## Cross-referencing with OSV

```sh
osv-scanner --sbom=sbom.cyclonedx.json
```

Should report any known advisories. Sojourn does this automatically
on its daily background refresh; the manual export is for ad-hoc
auditing.

## Troubleshooting

- **"`mpm sbom` exits with `unknown command`"** — your mpm is older
  than 5.18. Upgrade via `brew upgrade meta-package-manager`.
- **"Empty SBOM"** — `mpm sbom` reads from currently installed
  packages, not from `packages.toml`. Run `mpm restore` first to
  bring the local Mac into sync.
- **"SPDX validation fails"** — mpm's SPDX output may have
  out-of-spec fields; CycloneDX is the better choice for tooling
  compatibility.

## See also

- [reference/file-formats/packages-toml.md](../../reference/file-formats/packages-toml.md).
- [reference/cooldown-policy.md](../../reference/cooldown-policy.md)
  — OSV bypass uses the same data shape.
- [process/audit-2026-04.md §2.1.1](../../process/audit-2026-04.md#21-mpm-features-not-used)
  — original gap.
