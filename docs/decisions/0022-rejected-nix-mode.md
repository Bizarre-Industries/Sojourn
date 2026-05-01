# 0022 — REJECTED: Nix as a second backend ("Phase 2 mode")

- **Status**: Rejected
- **Date**: 2026-05-01
- **Deciders**: Sojourn maintainer

> **Why this ADR exists.** A rejected ADR is the canonical "why not"
> for a question that will be asked again. Future contributors
> evaluating Nix integration should read this first, then
> `lessons.md` "Drop Nix as a 'Phase 2 mode'" for the empirical
> backing. Two flip-conditions are documented at the bottom; if
> reality changes on either, write a new ADR proposing Nix and cite
> this one.

## Context

The v0.1 plan flirted with adding Nix (specifically nix-darwin) as an
alternative backend behind a `Backend` protocol — "in case users want
declarative purity later." The pitch was that nix-darwin's atomic
generations + bit-for-bit reproducible builds were strictly better
than brew's imperative model, and that Sojourn would be a friendlier
GUI for users who wanted Nix without learning Nix.

Three months of empirical evidence accumulated against this plan:

1. **macOS-Nix is unstable on Tahoe 26.x.** mas integration broken
   via nix-darwin
   ([nix-darwin#1627](https://github.com/nix-darwin/nix-darwin/issues/1627),
   November 2025); daemon `objc fork()` crash on early Tahoe builds
   ([NixOS/nix#13342](https://github.com/NixOS/nix/issues/13342));
   Determinate dropped Intel Mac in 3.13.2 (November 2025);
   APFS/Apple-Silicon/PAM-rewrite-on-update interactions break Nix
   in ways that are not a Lix or FlakeHub fork can fix.
2. **The store is expensive.** 5–20 GB Nix store; 30 s–5 min rebuilds
   for one-package adds. Sojourn's promise is "Mac config manager,"
   not "developer power tool"; an extra 10 GB on disk for the value
   proposition is wrong.
3. **Round-tripping config from a UI is hard.** Nix's strength is
   declarative source files; converting "user clicked toggle in
   Sojourn's macOS Features pane" into a flake edit is a constant
   impedance mismatch with no clean answer. brew's imperative model
   matches the GUI's mental model.
4. **The Nix-exclusive features that aren't covered by brew don't
   matter at this scale.** Bit-for-bit reproducibility and true
   atomic system rollback are team/CI features. Sojourn replicates
   ~85% of nix-darwin's atomic-rollback UX via git-tagged tarball
   snapshots + `brew bundle install --cleanup --file=<snapshot>` +
   `chezmoi apply` + plist restore. The 15% gap is bit-for-bit
   reproducibility, which costs 10 GB and a Nix learning curve to
   recover for a personal/homelab tool.

## Decision

**Nix is not added as a backend, mode, or option.** The `Backend`
protocol speculatively introduced in
[ADR-0010](./0010-native-brew-keep-mpm.md) is removed (per
[ADR-0018](./0018-drop-mpm-for-brew-bundle.md)) — single backend is
brew bundle.

The Generations panel (per `docs/process/plans/v0.2-plan.md`
§"GenerationsPane + GenerationService") replicates nix-darwin's
generations UX without ever touching `/nix`. Tarball snapshots under
`~/Library/Application Support/Sojourn/generations/N.tar.zst` contain
`Brewfile.common`, `Brewfile.<host>`, `prefs.toml`, `machines.toml`,
and the chezmoi state hash. Rollback runs the same sequence in
reverse.

`docs/explain/discover-pane.md` and `docs/explain/observability.md`
should NOT cite Nix as an alternative implementation strategy. New
contributors who suggest "what about Nix?" get pointed at this ADR.

## Flip conditions

This decision is reversed only if BOTH of the following are true:

1. **macOS-Nix stability significantly improves.** Concrete signal:
   nix-darwin#1627 (mas) closed for ≥ 6 months AND
   NixOS/nix#13342 closed for ≥ 6 months AND a major release of
   Determinate Nix (or upstream Nix on macOS) ships without daemon
   `fork()` regressions for two consecutive minor versions.
2. **Multi-machine drift becomes painful enough that bit-for-bit
   reproducibility justifies the cost.** Concrete personal-tool
   signal: two machines diverge at the same git SHA twice within
   a 30-day window. Tracked via GitHub label `repro-drift` on the
   Sojourn repo (label created at v0.2 ship time alongside this ADR;
   contributors apply it to issues that match the criterion). At ≥ 2
   such issues, this flip-condition fires.

If both conditions land, a new ADR proposes Nix as an alternative
backend (NOT a replacement) and cites this one as the prior rejection.

## Consequences

### Positive

- One backend means one fixture corpus, one IPC contract, one
  testing surface. ADR-0010's split is gone; ADR-0018's single
  brew-bundle backend is the path forward.
- No `/nix` store on user disks. No 10 GB tax. No Nix learning curve.
- App design is unblocked — UI patterns can assume imperative
  state-mutating semantics (the model brew/chezmoi/defaults all
  share) without an "and what does this mean in Nix mode?" branch.

### Negative

- Bit-for-bit reproducibility is not in v0.2 or v1. Users who need
  it must look elsewhere (vanilla nix-darwin without Sojourn).
- "What if I want declarative purity?" is now an open question with
  no Sojourn answer. If a contributor expects Nix-style guarantees,
  they will be disappointed.

### Neutral

- Lix and FlakeHub are real macOS-Nix improvements but don't
  address the underlying APFS/PAM-rewrite issues. Their existence
  doesn't change this rejection.

## Alternatives considered

- **Add Nix mode behind a feature flag** — rejected. Speculative
  YAGNI. CLAUDE.md "no Backend protocol just in case" rule
  encodes this.
- **Replace brew with Nix entirely (no brew at all)** — rejected.
  Same instability arguments but with worse migration cost.
- **Wait until macOS-Nix matures, then revisit** — accepted as the
  flip-condition mechanism above. This ADR stays in `Rejected`
  until a future ADR supersedes.
