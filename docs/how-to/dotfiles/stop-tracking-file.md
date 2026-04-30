# Stop tracking a dotfile

## Goal

Tell Sojourn to stop syncing a file across Macs without modifying or
deleting the file itself. Wraps `chezmoi forget`.

## Prereqs

- A dotfile currently tracked by Sojourn.
- The Dotfiles pane open on that file.

## Steps

1. **Open the file in the Dotfiles pane**.
2. Click *Stop tracking*. Sojourn shows a confirmation modal listing
   exactly what will happen:
   - The source file in the data repo will be removed (`chezmoi forget
     <target>`).
   - The destination file on this Mac is **not modified**.
   - Other Macs will lose the file from their data repo on next pull;
     their existing destination files are also not modified.
3. **Confirm**. Sojourn runs `chezmoi forget <path>`, commits the
   removal, and shows the next push as available.

## Verification

- The source file is no longer in `<data-repo>/`.
- `~/.<name>` (or wherever) still exists on this Mac.
- `chezmoi managed | grep <name>` returns nothing.
- After push + pull on Mac B: source is gone there too; destination on
  Mac B is unchanged.

## Re-tracking later

If you change your mind:

1. Open Dotfiles pane → *Add file*.
2. Pick the destination path. Sojourn calls `chezmoi add <path>` —
   re-imports the current contents.

## Differences from delete

- **Stop tracking**: source file removed from repo; destination
  preserved.
- **Trash via Cleanup**: destination file moved to Trash via
  `NSFileManager.trashItem`; source also removed.
- **`rm` manually**: never. Sojourn's invariant is "never `rm`"; use
  the trash flow if you actually want to delete.

## Troubleshooting

- **"Stop tracking greyed out"** — the file is part of an external
  (`.chezmoiexternal.toml`). Stop tracking the external instead.
- **"Mac B still applies the file after my push"** — Mac B may have
  cached the file in `~/.local/share/chezmoi/`. Pull + apply on Mac
  B; the apply step removes the cached source.
- **"Want to stop tracking on this Mac only"** — chezmoi forget is
  per-repo, not per-Mac. Use a per-Mac override (template guard) to
  skip rendering on this Mac instead.

## See also

- [reference/chezmoi-features.md](../../reference/chezmoi-features.md)
  §2.2.6.
- [reference/cleanup.md](../../reference/cleanup.md) — when to
  delete vs forget.
- [CLAUDE.md](../../../CLAUDE.md) "Do not auto-delete orphans" rule.
