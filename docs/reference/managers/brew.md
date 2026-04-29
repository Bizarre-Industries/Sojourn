# brew (Homebrew)

Primary package manager on macOS. ~80% of installed packages on a Mac dev
machine. v0.1 backend: `mpm`. v1.x backend: native `BrewService` per
[decisions/0010-native-brew-keep-mpm.md](../../decisions/0010-native-brew-keep-mpm.md)
(implementation-plan phase 13).

## Tier

**B** — auto-update, 7-day cooldown. See
[../cooldown-policy.md](../cooldown-policy.md).

## Binary detection

Hardcoded candidates (LaunchServices `PATH` is too thin for `which`):

- `/opt/homebrew/bin/brew` (Apple Silicon, primary)
- `/usr/local/bin/brew` (Intel, secondary)

Cache hit in `Settings.toolLocations` after first probe.

## Key invocations

| Goal | Command | Notes |
|---|---|---|
| Installed list | `brew info --json=v2 --installed` | Stable JSON. Use this. |
| Outdated | `brew outdated --json=v2` | Output flapped in bug #20976 (Nov 2025); treat as advisory. |
| Tap list | `brew tap --json` | See [extra-config.md](../extra-config.md) "Brew taps". |
| Services | `brew services list --json` | See [extra-config.md](../extra-config.md) "Brew services". |
| Bundle export | `brew bundle dump --file=Brewfile` | Brewfile interop for users migrating from `brew bundle`. |

## Auto-refresh

Homebrew's JSON API auto-refresh was 1 day, bumped to 7 days in PR
#21262 (Dec 2025). Sojourn does not override this; trusts upstream
defaults.

## Native swap (v1.x)

Per ADR-0010, `BrewService` becomes a native actor in v1.x. Reasons:

- Bus-factor: moves 80% of traffic off mpm's single-maintainer dependency.
- Unlocks taps + services + Brewfile interop natively (mpm doesn't
  surface them).
- Stable JSON API (`--json=v2`) — low maintenance burden.

## Install path

Sojourn installs Homebrew via signed `.pkg` per
[decisions/0008-no-curl-bash-for-brew.md](../../decisions/0008-no-curl-bash-for-brew.md).
See [reference/bootstrap-flow.md](../bootstrap-flow.md) "Homebrew install".

## Known issues

- `brew update` is slow on cold cache (~3 min). Sojourn allows 90s
  per-call timeout; longer waits surface as a job in the queue.
- Casks share the same CLI but live in [`cask.md`](cask.md) for tier
  separation.
