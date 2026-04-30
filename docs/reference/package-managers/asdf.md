# asdf

Tool version manager. **Not a service actor**; synced as
dotfile-classified config files per audit §2.4.8.

## Files synced

- `~/.tool-versions` — per-project version pin file (chezmoi via
  `private_dot_tool-versions.tmpl` if user wants per-machine variants).
- `~/.asdfrc` — global asdf config.
- `~/.asdf/plugins/` — list of installed plugins (the plugins
  themselves regenerate on `asdf install`).

## Why dotfile-classified

asdf reconciles itself on `asdf install` from `.tool-versions`. Sojourn
syncs the *manifest*, asdf does the work. No need for a service actor.

## Tier

n/a — see managers/README.md tier matrix.
