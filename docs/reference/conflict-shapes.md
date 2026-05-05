# Conflicts

> **Audit driver**: closes [process/audit-2026-04.md §1.6](../process/audit-2026-04.md#1-doc-level-inconsistencies)
> (eight shapes enumerated; shapes 7 + 8 added per
> [process/open-questions.md](../process/open-questions.md) §8) +
> drives [§2.2.3](../process/audit-2026-04.md#22-chezmoi-features-not-surfaced)
> (`chezmoi merge` swap for `apply --force` lands in implementation-plan
> Phase 12).

Sojourn's sync is explicit push/pull over a git remote. Pull must fully
complete — including conflict resolution — before push is allowed (see
[reference/sync-model.md](sync-model.md)). This doc enumerates conflict shapes
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

## Shape 2: Brewfile entry diverged

- Two Macs made different package changes; the Brewfile diff shows both
  versions of a given package declaration.
- `kind == .brewfile`.
- Resolution UX: merge entries by package. The UI groups by declaration type
  so the user doesn't manually scan the full Brewfile.

## Shape 3: chezmoi template conflict

- A template file (`dot_gitconfig.tmpl`) has incompatible conditional
  blocks between two Macs.
- `kind == .chezmoiTemplate`.
- Always surfaces to the user: we cannot safely auto-merge Go templates.

## Shape 4: plist conflict

`defaults` export to XML resolves the "binary plist diff is opaque"
problem, but XML diffs can still collide. Plist conflicts split into two
sub-shapes by resolution path:

### 4a: file-level divergence (auto-merge attempt)

- One Mac changed key A; the other changed key B; same domain.
- `kind == .plist`, `.subkind == .fileLevel`.
- `SyncCoordinator` attempts a key-merge: union of changed keys, both
  applied to the working-tree plist.
- Surfaces only on key collisions or on plist-structural conflicts
  (e.g., type changes, dict-vs-array on the same key).

### 4b: same-key divergence (keyed-diff UX)

- Both Macs changed the **same** key to different values.
- `kind == .plist`, `.subkind == .keyLevel`.
- UI shows a keyed diff (not text-line diff) — left side shows local
  value with type, right side shows remote value with type. User picks
  per-key.
- Required because plist semantics matter (type coercion, ordered-array
  identity, dict-vs-array distinctions).

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

## Shape 7: encrypted file conflict

- Both Macs edited an `encrypted_*.age` file between syncs.
- `kind == .encryptedDivergence`.
- Resolution UX is fundamentally different from shape 1: Sojourn cannot
  show the user a content diff without a recipient key that decrypts
  *both* sides. Three resolution paths:
  1. **Local key decrypts both** → fall through to shape 1 with the
     decrypted plaintexts; re-encrypt on commit. This is the common case
     when the user is the only recipient.
  2. **Local key decrypts one side only** → ciphertext-only resolution.
     UI shows commit-timestamp + author per side and asks "Keep local /
     Keep remote." No content diff.
  3. **Local key decrypts neither side** (wrong recipient) → abort with
     guidance: "This file is encrypted to recipients you don't have a key
     for. Resolve on a Mac with the correct key."
- Always surfaces; never auto-resolves.

## Shape 8: secret-broker reference vs. inline value

- One Mac wrote a templated secret reference
  (`{{ onepasswordRead "op://Vault/AWS/access_key_id" }}`); the other
  Mac wrote an inline plaintext value (e.g. during a broker-outage
  fallback or a manual edit).
- `kind == .secretBrokerVsInline`.
- Auto-resolves to **keep the template form**; the plaintext is a leak
  waiting to happen and gitleaks may not catch it (template-side
  patterns don't match arbitrary user-formatted values).
- Logged to `history.db` with `reason = 'auto-prefer-template-secret'`.
- User can override per-resolution; override prompts a gitleaks rescan
  before commit and a 5s lockout per
  [reference/cooldown-policy.md](cooldown-policy.md) lockout pattern.

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
[reference/sync-model.md](sync-model.md).

## Multi-way merges (out of scope for v1)

Sojourn assumes one writer at a time, enforced by the cooperative writer
lock (`.sojourn/active.toml`). The lock is best-effort, not authoritative
— git has no locking. If two writers race past the lock, the second
writer's pull encounters a multi-way diff (local branch and remote share
a common ancestor that's behind on both sides). Sojourn **refuses** to
auto-merge multi-way diffs and surfaces a "multi-way race" error: the
user picks a winning branch and rebases manually, or aborts and resolves
on a single Mac.

This is not "the second-to-arrive sees one merge at a time" — git doesn't
serialise by arrival; the race produces a genuine three-or-more-way diff
that requires human judgement.

## Out of scope (v1)

- Auto-merge of multi-way diffs (above).
- Resolving binary content (images, compiled plists) beyond "keep local
  / keep remote".
- Automatic 3-way merge for `packages.toml` — always surfaces.
- Decrypting age-encrypted files with a recipient key the user does not
  hold (shape 7 case 3).
