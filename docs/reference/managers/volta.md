# volta

Node.js + JS toolchain manager ([volta-cli/volta](https://github.com/volta-cli/volta)).
**Not a service actor**; synced as dotfile-classified per audit §2.4.8.

## Files synced

- `~/.volta/log/` and `~/.volta/tmp/` — excluded.
- `~/.volta/tools/inventory/` — list of installed tool versions
  (advisory; volta will re-fetch as needed).
- Per-project `package.json` `volta` field — already in user's project
  repos.

## Tier

n/a.
