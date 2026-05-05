# 0019 — Cask declares `depends_on formula: chezmoi, mas`

- **Status**: Accepted
- **Date**: 2026-05-01
- **Deciders**: Sojourn maintainer

## Context

Sojourn ships as a Homebrew Cask (`brew install --cask
Bizarre-Industries/sojourn/sojourn`). The cask delivers `Sojourn.app`;
the runtime backend tools (`chezmoi`, `mas`, `git`, `brew` itself) are
expected to exist in the user's `PATH`. Sojourn's
`BootstrapCoordinator` probes for them and prompts an install via
`ToolInstaller` if missing.

The bootstrap flow is fine for users running Sojourn for the first
time inside the GUI. But two scenarios skip it:

1. A user installs the cask, opens it, hits "Push" before bootstrap
   completes, and the call fails because `chezmoi` is not yet
   installed.
2. A user inspects `brew info sojourn` for discoverability — Cask
   metadata is the canonical place to declare runtime deps.

The Cask Cookbook supports `depends_on formula: [...]` exactly for
this case (per `docs/process/plans/v0.2-plan.md` §"Cask rewrite";
[Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)).

## Decision

`Casks/sojourn.rb` declares:

```ruby
depends_on macos: ">= :tahoe"
depends_on formula: ["chezmoi", "mas"]
```

`brew install --cask sojourn` installs `chezmoi` and `mas` first if
they are not already present. `git` is not declared (provided by Xcode
CLT, which `brew` itself depends on transitively). `age` and
`gitleaks` stay bundled per [ADR-0009](./0009-bundle-binary-policy.md)
(belt + suspenders — bundled binary fast-path, formula fallback if the
cask is invoked on a machine where the bundled binary fails Gatekeeper
for any reason).

`Brewfile.common` (the chezmoi-managed declarative source) **also**
lists `chezmoi` and `mas` as `brew "chezmoi"` / `brew "mas"` so
Sojourn's own snapshots round-trip the same dependencies for users
who `brew bundle install` into a fresh machine before installing the
Sojourn cask.

## Consequences

### Positive

- `brew info sojourn` lists runtime deps; users discover them via
  the standard brew metadata flow.
- "Open Sojourn for the first time, click Push" works because the
  formulae installed during the cask install.
- One source of truth: cask's `depends_on` matches Sojourn's own
  bootstrap probe list. Drift impossible.
- mas is now Touch-ID-gated for `mas install`/`mas upgrade` per
  CVE-2025-43411 (lessons.md "mas requires sudo on macOS 14.8.2+ /
  15.7.2+ / 26.1+"); having mas installed early surfaces the helper
  prompt before the user is mid-flow.

### Negative

- `brew install --cask sojourn` is slightly slower on first run (one
  extra `brew install chezmoi mas` step). Acceptable — both formulae
  are small.
- Users who already manage `chezmoi`/`mas` outside brew (rare; both
  are brew-distributed in 99% of installs) get a duplicate install
  attempt that brew skips with a "already installed" message. Cosmetic.

### Neutral

- `BootstrapCoordinator`'s probe still runs at app launch — both as a
  re-verification (in case user ran `brew uninstall chezmoi` after
  installing Sojourn) and to detect `git`, `brew`, `age`, `gitleaks`
  which are not formula deps.
- `git`/`brew` not declared because brew itself requires them; cask
  installation implies brew is installed, which implies CLT (and thus
  git) per Homebrew bootstrap.
- v0.4 Stage 3 narrows what the privileged MAS helper will execute:
  the cask still declares `mas` for discovery, inventory, and normal
  CLI availability, but root helper install/upgrade is disabled unless
  `/opt/homebrew/bin/mas` is reachable through a root-owned,
  non-group-writable path. A standard user-writable Homebrew formula
  remains visible to Sojourn but is not trusted for root execution.

## Alternatives considered

- **Don't declare any formula deps; rely entirely on
  `BootstrapCoordinator`** — rejected. Discoverability via
  `brew info` matters; bootstrap-only means the user must launch the
  app once before getting deps, breaking command-line workflows.
- **Declare every backend: chezmoi, mas, age, gitleaks, git** —
  rejected. age and gitleaks ship bundled per ADR-0009; declaring
  them in cask either duplicates or invalidates the bundled-binary
  policy. git is implicit via brew. Keep the list tight.
- **Use `depends_on cask: [...]` instead of `formula:`** — rejected.
  Both `chezmoi` and `mas` are formulae upstream, not casks.
