# gem

Ruby package installer. Backend: `mpm`. Tier **D** (prompt, 7d).

## Binary

`~/.gem/bin/gem` or system `/usr/bin/gem` (deprecated path).

## Key invocations

- `gem list --local` — installed.
- `gem outdated` — outdated.

## Known issues

- mpm's `gem` fix #389 removed `--user-install` so list/outdated scopes
  match. ADR-0010 cites this as why mpm earns its keep here.
- macOS system Ruby is end-of-life; users should install via `brew
  install ruby` and switch via `chruby` / `rbenv` (sync as dotfile).
