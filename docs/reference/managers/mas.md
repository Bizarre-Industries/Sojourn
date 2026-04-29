# mas (Mac App Store CLI)

[mas-cli/mas](https://github.com/mas-cli/mas) wraps the Mac App Store
purchase + install API. v0.1 backend: `mpm`. v1.x backend: native
`MasService` (~80 LOC) per ADR-0010.

## Tier

**A** — auto, 0-day cooldown. Apple reviews every MAS app; silent
auto-update is safe.

## Binary

`/usr/local/bin/mas` (Homebrew formula). On Apple Silicon: `/opt/homebrew/bin/mas`.

## Key invocations

- `mas list` — installed Mac App Store apps + version + numeric app ID.
- `mas outdated` — outdated apps.
- `mas install <id>` — install by numeric ID.
- `mas account` — signed-in Apple ID (Sojourn surfaces this in Bootstrap).

## Known issues

- `mas install` requires the user to be signed in to the App Store. If
  not, the install fails with a clear error; Sojourn surfaces this.
- App must already be associated with the signed-in Apple ID (purchased
  or downloaded once on this account).
