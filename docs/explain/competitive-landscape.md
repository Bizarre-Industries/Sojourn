# Competitive landscape

The market splits into four archetypes; none cover Sojourn's scope.

## Brew-GUI archetype

Cork, Applite, Brewer X, Cakebrew, Latest, MacUpdater, CleanMyMac. **Packages
only.**

- **Cork** (buresdv, v1.7.4 Mar 2026, ~4.4k★, GPL-3 with paid binaries via
  Paddle at €25, source is open).
- **Applite** (milanvarady, v1.3.1, MIT, free) explicitly refuses to grow
  past casks — "too technical".
- **Brewer X** ($49 one-time, proprietary).
- **Cakebrew is dead** (v1.3, March 2021, owner confirmed no plans).
- **MacUpdater was discontinued 2026-01-01**, now free-frozen, DB server
  running only through year-end.
- **CleanMyMac** is a cleaner, not a setup tool.
- **Latest** (mangerlahn) tracks Sparkle + MAS apps only, low coverage.

## Dotfile-CLI archetype

chezmoi v2.70.2, dotbot, yadm, rcm, stow, Mackup. chezmoi is the technical
winner and Sojourn's backend.

**Mackup**, the incumbent for app-prefs, has been **effectively broken since
Monterey**: its own README now ships a WARNING banner that link mode destroys
preferences on Sonoma+. PR #2085 added copy mode as a fallback, but it is
still not a live sync. Last release 0.8.43, March 2025 — low-velocity
maintenance, not abandoned. This is the biggest open wound for non-nerds.

## Declarative / Nix archetype

nix-darwin (moved to `nix-darwin/nix-darwin` org), home-manager, Determinate
Systems. The only existing tools that genuinely unify packages + dotfiles +
macOS defaults. Steep learning curve, Nix language, flakes. Determinate
Systems has **no consumer Mac GUI** as of v3.13.2 (Apple Silicon only now).
The addressable market for nix-darwin caps at the top 2% of developers.

## Adjacent AI-terminal archetype

Warp, Amazon Q Developer CLI. Warp has Settings Sync (Beta) but it syncs only
**Warp's own** settings and documents shell-dotfile incompatibilities.
Amazon Q (née Fig, sunset September 2024) is CLI autocomplete. Neither
competes.

## Closest near-peer

OpenBoot, a TUI that claims to capture and restore brew packages, dotfiles,
shell config, and macOS prefs. Small project, not GUI. Direct confirmation
that the thesis is valid.

## Strong direct signal

April 2026 HN thread "Show HN: It's 2026 and setting up a Mac for development
is still mass googling" explicitly says:

> Brewfile handles packages but not your shell. chezmoi handles dotfiles but
> not packages. nix-darwin handles everything but good luck onboarding a
> junior with it. Nothing just does the whole thing.

## Gap

No product unifies packages + dotfiles + app-prefs + explicit cross-machine
push/pull in a native Mac GUI for the mainstream developer. Sojourn fills it.
