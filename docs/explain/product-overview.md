# Product overview

**Sojourn is a native macOS app that carries your Mac setup — apps, packages,
shell configs, and app preferences — across machines and across time.**

It wraps `mpm` and `chezmoi` behind a GUI aimed at users who don't want to
learn Nix or write Go templates. Explicit push/pull between machines,
git-backed rollback of every change, scheduled package updates with a
supply-chain-attack cooldown, and automatic cleanup of dotfile cruft from
uninstalled tools.

Time Machine for the parts of your Mac that Time Machine doesn't actually
restore well.

For the gap analysis Sojourn fills and the products it does *not* try to
replace, see [explain/why-sojourn.md](why-sojourn.md).

For the v1 scope cut and what's deferred, see
[process/implementation-plan.md](../process/implementation-plan.md).
