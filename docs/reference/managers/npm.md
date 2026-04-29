# npm

Node.js package manager. Backend: `mpm`. Tier **E** (never silent, 14d
cooldown). Highest-risk manager because of `preinstall` / `postinstall`
script execution and the 2024–2026 incident pattern (axios, Shai-Hulud,
chalk/debug, ua-parser-js — see [../cooldown-policy.md](../cooldown-policy.md)).

## Binary

`~/.npm-global/bin/npm`, `/opt/homebrew/bin/npm`, or wherever `node` was
installed.

## Key invocations

- `npm list -g --json --depth=0` — installed global packages.
- `npm outdated -g --json` — outdated globals.
- `npm install -g <pkg>` — install global.

## Hard rules

- **Never auto-install silently.** Tier E gate. User must approve each
  version.
- Lifecycle scripts (`preinstall`/`postinstall`) require explicit consent
  even inside cooldown — see [../cooldown-policy.md](../cooldown-policy.md)
  hard rule.
- Advisory bypass: if OSV/GHSA flags the **old** version, bypass cooldown
  and update.

## Known issues

- npm registry has the most active supply-chain incidents. Sojourn's
  tier-E gate is the single biggest user-protection feature.
- mpm absorbs npm workspaces, registry auth, classic-vs-berry split per
  ADR-0010.
