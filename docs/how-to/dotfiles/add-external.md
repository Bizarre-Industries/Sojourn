# Add a chezmoi external

## Goal

Pull a third-party shell framework or repo (oh-my-zsh, prezto,
lazy.nvim, tpm) into the data repo via `.chezmoiexternal.toml` so
every Mac that onboards gets it automatically.

## Prereqs

- A target home-relative path the external should land at (e.g.
  `~/.oh-my-zsh`).
- The upstream URL: a git repo, archive URL, or HTTP file.

## Steps

1. **Open the Dotfiles pane → Externals tab**.
2. Click *Add external*. Sojourn shows a form:
   - **Type**: `git-repo`, `archive`, or `file`.
   - **URL**: the upstream source.
   - **Target**: home-relative path (e.g. `.oh-my-zsh`).
   - **Refresh period**: e.g. `168h` (1 week).
3. **Submit**. Sojourn writes a block to
   `<data-repo>/.chezmoiexternal.toml`:

   ```toml
   [".oh-my-zsh"]
       type = "git-repo"
       url = "https://github.com/ohmyzsh/ohmyzsh.git"
       refreshPeriod = "168h"
   ```
4. **Run `chezmoi update`** via *Externals → Refresh* to pull the
   external on this Mac.
5. **Push** — peer Macs get the external on next pull + apply.

## Verification

- `<data-repo>/.chezmoiexternal.toml` lists your new external.
- `~/.oh-my-zsh/` exists with the upstream content.
- A second Mac that pulls + applies gets the same content at the same
  path.

## Troubleshooting

- **"External not refreshing"** — `refreshPeriod` is shorter than the
  time since last refresh. Force with *Externals → Force refresh*.
- **"GitHub rate-limiting"** — the daily refresh hits GitHub's anon
  rate limit fast for archive externals. Use `git-repo` type which
  uses git protocol (no rate limit) instead of archive type.
- **"Mac B's external is empty"** — `chezmoi apply` doesn't fetch
  externals; only `chezmoi update` does. Run *Externals → Refresh on
  apply* from Settings.

## See also

- [reference/externals.md](../../reference/externals.md) — full
  external types + format reference.
- [reference/chezmoi-features.md](../../reference/chezmoi-features.md)
  — Phase 12 wiring.
- [process/audit-2026-04.md §2.2.1](../../process/audit-2026-04.md#22-chezmoi-features-not-surfaced)
  — original gap.
