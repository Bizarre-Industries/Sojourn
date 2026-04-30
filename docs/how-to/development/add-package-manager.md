# How to add a package manager

Two paths depending on whether `mpm` covers it:

## Path A — mpm covers the manager

If [kdeldycke/meta-package-manager](https://github.com/kdeldycke/meta-package-manager)
already supports the manager, you just need to wire it in:

1. Add a `PackageManager` case in `Sojourn/Models/ManagerSnapshot.swift`
   (id, display name, CLI binary name).
2. Add detection in `Sojourn/Services/ToolLocator.swift` if the binary
   lives outside the default candidate paths.
3. Add the manager to the list `MPMService` fans out to. No new actor.
4. Classify a tier in `Sojourn/Models/AutoUpdateTier.swift`'s
   `ManagerTier.defaults`. Default to `.c` if unsure. See
   [reference/cooldown-policy.md](../../reference/cooldown-policy.md).
5. Add fixture-backed tests under `SojournTests/Services/`. Use real
   captured output, not generated.
6. Wire into `AppStore` aggregation so the UI sees uniform results.
7. Add a per-manager doc page under
   [reference/package-managers/](../../reference/package-managers/).
8. Update [reference/package-managers/index.md](../../reference/package-managers/index.md)
   matrix.

## Path B — mpm does not cover the manager

Two sub-paths: native Swift actor (for first-party support) or plugin
(for community-maintained support).

### B1 — Native Swift actor

Use this for managers Sojourn first-party supports (e.g., the planned
native `BrewService`/`CaskService`/`MasService` per
[decisions/0010-native-brew-keep-mpm.md](../../decisions/0010-native-brew-keep-mpm.md)).

1. Create `Sojourn/Services/<Name>Service.swift` parallel to `MPMService`.
2. Conform to `PackageBackend` protocol (lands in implementation-plan
   phase 10).
3. Implement: `installed()`, `outdated()`, `install(pkgs:)`,
   `remove(pkgs:)`, `upgrade(pkgs:)`. Return `ManagerSnapshot` shape.
4. All other steps from Path A.

### B2 — Plugin

Use this for community-maintained managers (e.g., `pnpm`, `mise`, `gh
extension`). See [reference/plugin-protocol.md](../../reference/plugin-protocol.md).

1. Create a `<name>.sojourn-plugin/` directory:
   ```
   <name>.sojourn-plugin/
   ├── manifest.toml
   └── plugin               # executable
   ```
2. Implement the JSON-RPC methods (`manifest`, `installed`, `outdated`,
   `install`, `remove`, `upgrade`).
3. Sign with cosign; embed public key in `manifest.toml`.
4. Distribute via the Sojourn plugin registry (TBD) or sideload via
   Settings → Plugins → Install from URL/folder.

## Cross-cutting steps

Regardless of path:

- Add an entry to `data/applications/README.md` registry if the manager
  also has a plist domain (rare for package managers).
- Add to `BootstrapService` as an on-demand install option (don't install
  upfront; first time the user tries to sync a `<name>`-tracked package,
  offer `brew install <backend>` in a sheet).
- Document any quirks in the per-manager page.
