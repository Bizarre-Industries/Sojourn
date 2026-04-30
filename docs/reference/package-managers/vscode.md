# vscode (extensions)

VS Code extension installer. Backend: `mpm`. Tier **C** (prompt, 7d).

## Binary

`code` (VS Code) or `cursor` (Cursor) — extension CLI is invoked as
`code --list-extensions`. Sojourn handles both.

## Key invocations

- `code --list-extensions --show-versions` — installed.
- `code --install-extension <ext>` — install.

## Known issues

- Some extensions run setup scripts on install — tier C prompt.
- VSCodium and Cursor share the same extension format but distinct
  marketplaces. Sojourn does not auto-translate.
- Extensions registry is moving toward Open VSX; mpm tracks both.
