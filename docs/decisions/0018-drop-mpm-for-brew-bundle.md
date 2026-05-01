# 0018 — Drop mpm; brew bundle is the single backend

- **Status**: Accepted
- **Date**: 2026-05-01
- **Deciders**: Sojourn maintainer
- **Supersedes**: [0010](./0010-native-brew-keep-mpm.md)

## Context

ADR-0010 (April 2026) split package-management between native Swift
services (brew/cask/mas) and `mpm` for the long tail (pip, pipx, uvx,
npm, yarn, gem, composer, cargo, vscode). The split was justified by
mpm's bus-factor on 80% of traffic moving to native, with mpm earning
its keep on managers where Sojourn would otherwise reimplement scope
semantics.

In the eight months since, brew bundle's coverage expanded materially.
The 2026 Brewfile grammar natively manages 11 ecosystems —
`brew "x"`, `cask "y"`, `mas "z", id: 123`, `vscode "ms-python.python"`,
`go "github.com/x/y"`, `cargo "ripgrep"`, `uv "ruff"`, `krew "ns"`,
`flatpak "com.foo.bar"`, `npm "typescript"`, `tap "user/repo"`. PHP
fills via `shivammathur/php` tap; Ruby gems via `sportngin/brew-gem`.
Tool version managers go through `mise` installed as a brew formula.
The remaining mpm-only managers (pipx, uvx, yarn, composer) cover a
small fraction of the audit's traffic profile and can be addressed via
Brewfile lines (`uv "ruff"` covers uvx) or deferred without
material loss.

mpm is a single-maintainer Python project; `MPMService` and the
speculative `Backend` protocol carry maintenance overhead the v0.2
pivot can shed. Single backend is cheaper than two with no measurable
coverage gap. lessons.md "Drop mpm for brew bundle — 2026-05-01"
captures the empirical case.

## Decision

Sojourn ships exactly one package backend: **brew bundle**. The
`Brewfile` grammar — committed to chezmoi at
`<chezmoi-source>/dot_config/sojourn/Brewfile.common` and
`Brewfile.<hostname>` — is the declarative source of truth. Layered
install runs `brew bundle install --file=Brewfile.common` followed by
`brew bundle install --file=Brewfile.<hostname>`.

`Sojourn/Services/MPMService.swift` is deleted. `Sojourn/Backends/`
(the `Backend`/`PackageBackend`/`DotfileBackend`/`PrefBackend`
abstraction) is deleted — YAGNI with one backend. `BrewBundleService`
replaces both. Cooldown tiers per Brewfile line type, per-package
overrides in `~/Library/Application Support/Sojourn/cooldowns.toml`:

- mas → tier A (0 d)
- homebrew/core brew → B (7 d)
- third-party tap brew → C (14 d)
- homebrew/cask → C (14 d)
- third-party cask → D (21 d)
- vscode → D (21 d)
- cargo / npm / go / uv / krew → E (30 d)

Brewfile output flaps between brew minor versions — parse to AST,
compare AST in tests; never compare raw strings (lessons.md "brew JSON
output flaps", [Homebrew/brew#20976](https://github.com/Homebrew/brew/issues/20976)).

## Consequences

### Positive

- One service, one fixture corpus, one IPC contract — half the
  testing surface vs ADR-0010's split.
- Brewfile is human-editable; advanced users can `vim` it directly
  and Sojourn re-reads on next sync.
- `brew bundle dump --describe` round-trips current state into the
  same grammar — capture-and-restore symmetry.
- mpm bus-factor risk eliminated by removal, not mitigated.
- Package.swift drops the (speculative) `mpm` adapter target.

### Negative

- No coverage of pipx, yarn, composer, etc. without brew taps. Users
  who need those manage them outside Sojourn (or via `mise` for
  runtime-version managers).
- Brew formula installs are gated by Homebrew's own cadence; if
  upstream taps go stale, Sojourn cannot route around them.
- Migration cost for any v0.1 user: their `packages.toml` is mpm's
  TOML format; conversion to Brewfile is one-shot mechanical but not
  zero.

### Neutral

- ADR-0010's `PackageBackend` protocol is removed without replacement.
  If a future ADR re-introduces a second backend, refactoring then is
  cheaper than carrying a speculative interface now (lessons.md "Drop
  Nix as a 'Phase 2 mode'").
- Cargo classification reopens as
  [open-questions.md §1](../process/open-questions.md). Brewfile's
  `cargo "ripgrep"` line covers most cases; `~/.cargo/config.toml`
  goes through chezmoi as a dotfile.

## Alternatives considered

- **Keep ADR-0010's split** — rejected. The bus-factor case for mpm has
  weakened (single maintainer, slower release cadence in 2026), and
  brew bundle's grammar now covers the high-value managers. Two
  backends to maintain when one suffices is YAGNI.
- **All-native rewrite (drop both mpm and brew bundle, write
  per-manager Swift services)** — rejected. Reimplements years of
  pip/npm/gem scope semantics. Brew handles them via taps with no
  Sojourn-side code.
- **All-mpm (revert ADR-0010 in the other direction)** — rejected. Bus
  factor + lower coverage of new ecosystems (krew, uv) than Brewfile.
- **Add Nix as a second backend (the speculative "Phase 2 mode")** —
  rejected per [0022-rejected](./0022-rejected-nix-mode.md). macOS-Nix
  is unstable on Tahoe; Sojourn replicates ~85% of nix-darwin's
  generations UX without ever touching `/nix`.
