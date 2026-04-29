# cask (Homebrew Cask)

GUI app installer that shares the brew CLI. v0.1 backend: `mpm`. v1.x
backend: native `CaskService` (sibling of [`BrewService`](brew.md)) per
ADR-0010.

## Tier

**C** — user prompt, 7-day cooldown. Casks run installer scripts on
install/uninstall; never auto-install silently.

## Binary

Same as brew (`/opt/homebrew/bin/brew` or `/usr/local/bin/brew`).

## Key invocations

- `brew info --json=v2 --installed --cask` — list installed casks.
- `brew outdated --cask --json=v2` — outdated casks.
- Cask metadata exposes `artifact_dependencies` (other casks/formulae the
  cask requires); Sojourn surfaces these.

## Known issues

- Some casks ship `installer` blocks that need root. The signed `.pkg`
  Authorization model does not extend to casks; Sojourn surfaces the
  `sudo` requirement and pauses for user action.
- Cask `auto_updates true` casks (Chrome, Slack, etc.) don't surface
  outdated state to brew. Sojourn marks them with a "self-updating"
  badge.
