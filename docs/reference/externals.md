# chezmoi externals

`.chezmoiexternal.toml` is the canonical mechanism for pulling files /
archives / git repos into the chezmoi source tree from external URLs. It is
the answer to "I want to carry my whole shell setup including `oh-my-zsh`,
`prezto`, `antidote`, `tpm`, `lazy.nvim`, `vim-plug`."

Audit
[process/audit-2026-04.md §2.2.1](../process/audit-2026-04.md#22-chezmoi-features-not-surfaced)
flagged this as a v1-blocker for the "carry whole shell setup" workflow.
Surface UX lands in implementation-plan phase 12.

## Format

`.chezmoiexternal.toml` lives at the chezmoi source root. Each entry maps a
**target path** (relative to `$HOME`) to a fetch spec:

```toml
[".oh-my-zsh"]
    type = "git-repo"
    url = "https://github.com/ohmyzsh/ohmyzsh.git"
    refreshPeriod = "168h"  # 7 days

[".tmux/plugins/tpm"]
    type = "git-repo"
    url = "https://github.com/tmux-plugins/tpm.git"
    refreshPeriod = "168h"

[".vim/autoload/plug.vim"]
    type = "file"
    url = "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    refreshPeriod = "168h"

[".local/share/lazy.nvim"]
    type = "archive"
    url = "https://github.com/folke/lazy.nvim/archive/refs/heads/main.tar.gz"
    refreshPeriod = "168h"
    stripComponents = 1
```

## Type values

| `type` | Use |
|---|---|
| `file` | Single file, no extraction. |
| `archive` | tar/zip archive; extracted into target dir. |
| `archive-file` | Single file extracted from inside an archive. |
| `git-repo` | Clone (depth=1 by default); refreshed on `chezmoi update`. |

## refresh

`chezmoi update` invokes the externals refresh; `chezmoi apply` does not by
default. Sojourn surfaces a manual "Refresh externals" trigger plus an
auto-refresh schedule per the cooldown policy
([reference/cooldown-policy.md](cooldown-policy.md)).

## Sojourn UX

- **First-class subsection** in the Dotfiles pane (audit §4.1.1).
- CRUD on type/URL/refreshPeriod.
- Manual `chezmoi update` trigger.
- URL allowlist enforcement (default-deny for non-https; user override per
  domain).
- Stale-marker UI when `refreshPeriod` exceeded (advisory; not auto-pull).

## Security model

External URLs are a supply-chain surface. Defaults:

- **HTTPS-only** — `http://` rejected.
- **No `file://` URLs** — would bypass the model entirely.
- **Pin by commit/tag** when the user asks for it (chezmoi supports
  `refspec` on git-repo type).
- **Default-deny non-allowlisted domains** for new entries; user must
  explicitly accept the host on first use.

User-customizable allowlist lives at
`~/Library/Application Support/Sojourn/externals-allowlist.toml`.

## How-to

See [how-to/dotfiles/add-external.md](../how-to/dotfiles/add-external.md)
for the click-by-click flow.
