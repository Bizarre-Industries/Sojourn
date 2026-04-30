# Sojourn CLI (placeholder)

There is no `sojourn` CLI in v0.1 or v1.0. This URL is reserved for
the v1.x companion CLI tracked in
[process/future.md](../process/future.md) "Headless / CLI" section.

## Planned scope (v1.x)

If shipped, the CLI would expose the subset of Sojourn that doesn't
need a GUI:

- `sojourn pull` — perform a pull with confirmation TTY prompts.
- `sojourn push` — perform a push.
- `sojourn status` — show writer-lock + outdated-package state.
- `sojourn diagnose` — emit the diagnostics bundle to stdout / a
  path.
- `sojourn doctor` — wrap `chezmoi doctor` and print Sojourn-specific
  health (FDA, tool detection, repo schema).
- `sojourn run-once <intent>` — re-run an `mpm restore`,
  `chezmoi apply`, or `defaults import` for fleet automation.

The GUI would still be the primary interface; the CLI is for
headless / fleet / CI scenarios.

## Why deferred

- v1 ships the GUI experience; CLI duplicates orchestration logic
  that would have to track every GUI feature.
- Most CLI use cases are already covered by direct invocation of the
  underlying tools (`mpm`, `chezmoi`, `git`).
- Shipping a CLI surfaces additional dependencies (a `sojourn`
  binary in `$PATH`) that complicate the Mac App Store-incompatible
  story (already incompatible per
  [explain/trade-offs.md](../explain/trade-offs.md), but a CLI also
  needs a brew tap or post-install symlink).

## Out of scope

- Cross-Mac SSH-style remote orchestration.
- A REPL / interactive shell.
- A daemon / agent / always-running background service that isn't
  the scheduled `NSBackgroundActivityScheduler` already shipped.

## See also

- [process/future.md](../process/future.md) — deferred-work tracking.
- [explain/trade-offs.md](../explain/trade-offs.md) — why fleet /
  team / org features are out of scope.
