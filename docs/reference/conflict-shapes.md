# Conflicts

Sojourn's sync is explicit push/pull over a git remote. Pull must fully
complete — including conflict resolution — before push is allowed (see
[ARCHITECTURE.md](ARCHITECTURE.md) §6). This doc enumerates conflict shapes
and how `SyncCoordinator` + the UI resolve them.

## Shape 1: text file edited on two Macs

Example: both Macs edited `dotfiles/.zshrc` between syncs.

- Pull phase surfaces a `Conflict` with `kind == .textEdit`. Three
  contents are kept in memory: `localContent`, `remoteContent`,
  `ancestorContent` (common-ancestor commit).
- UI: `ConflictResolutionView` offers Keep local / Keep remote / open a
  manual-merge editor.
- On Keep remote, `SyncCoordinator` writes `remoteContent` into the
  working tree then runs `chezmoi apply` to push that back into the
  live dotfile.

## Shape 2: `packages.toml` entry diverged

- Two Macs ran different `mpm install/remove`; the TOML diff shows both
  versions of a given manager's section.
- `kind == .packagesToml`.
- Resolution UX: merge keys per-manager. The UI groups by manager so
  the user doesn't manually scan the full TOML.

## Shape 3: chezmoi template conflict

- A template file (`dot_gitconfig.tmpl`) has incompatible conditional
  blocks between two Macs.
- `kind == .chezmoiTemplate`.
- Always surfaces to the user: we cannot safely auto-merge Go templates.

## Shape 4: plist (binary) conflict

- `defaults` export to XML resolves the "binary plist diff is opaque"
  problem, but XML diffs can still collide on the same key with
  different values.
- `kind == .plist`.
- UI shows keyed diff (not text-line diff).

## Shape 5: rename vs. edit

- One Mac renamed a file, the other edited it.
- `kind == .rename`.
- Always surfaces; git's rename detection feeds the hint but the user
  picks final path.

## Shape 6: delete vs. edit

- One Mac removed a file (e.g. `chezmoi forget`), the other edited it.
- `kind == .delete`.
- Default recommendation: keep the edit; the delete probably intended
  the old content.

## Cooperative lock (`.sojourn/active.toml`)

This file names the Mac currently syncing, but git does not enforce
locking. If two Macs both write to it at once, the second one sees the
first's commit on pull and must handle it as a standard conflict. The
lock is a *hint*, not a guarantee.

## Snapshot guarantee

Every pull creates a pre-op snapshot under
`~/Library/Application Support/Sojourn/backups/<ISO8601>-sync.pull/`
before writing anything to the working tree. If resolution goes wrong,
the user can restore from there. 30-day retention; see
[ARCHITECTURE.md](ARCHITECTURE.md) §6.

## Out of scope (v1)

- Multi-way merges (more than two Macs diverging simultaneously). The
  second-to-arrive sees one merge at a time.
- Resolving binary content (images, compiled plists) beyond "keep
  local / keep remote".
- Automatic 3-way merge for `packages.toml` — always surfaces.
