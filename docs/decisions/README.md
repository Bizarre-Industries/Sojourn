# ADR log

Architectural Decision Records for Sojourn. Each ADR is one page or less,
follows [MADR](https://adr.github.io/madr/) reduced. ADRs are immutable
post-`Accepted`; supersede via a new ADR. See
[../process/DOCS_POLICY.md](../process/DOCS_POLICY.md#adr-rules) for the rules.

## Template

[_template.md](_template.md) — copy when adding a new ADR.

## Index

| ID | Title | Status | Supersedes | Superseded by |
|---|---|---|---|---|
| [0001](0001-ipc-not-linking.md) | IPC, not linking | Accepted | — | — |
| [0002](0002-no-symlink-preferences.md) | No symlink preferences | Accepted | — | — |
| [0003](0003-cooldown-7-days.md) | Default 7-day cooldown | Accepted | — | — |
| [0004](0004-gpl-3-or-later.md) | GPL-3-or-later | Accepted | — | — |
| [0005](0005-no-tca.md) | No TCA, use @Observable | Accepted | — | — |
| [0006](0006-gitleaks-bundled.md) | Bundle gitleaks | Accepted | — | — |
| [0007](0007-shell-out-to-git.md) | Shell out to /usr/bin/git | Accepted | — | — |
| [0008](0008-no-curl-bash-for-brew.md) | No `curl \| bash` for brew install | Accepted | — | — |
| [0009](0009-bundle-binary-policy.md) | Bundle gitleaks + age; not mpm + chezmoi | Accepted | — | — |
| [0010](0010-native-brew-keep-mpm.md) | Native brew/cask/mas; keep mpm for the rest | Superseded | — | [0018](0018-drop-mpm-for-brew-bundle.md) |
| [0011](0011-secret-broker-abstraction.md) | Secret broker abstraction | Proposed | — | Supplemented by [0016](0016-secret-broker-order-and-cache.md) |
| [0012](0012-cooperative-writer-lock.md) | Cooperative writer lock | Accepted | — | — |
| [0013](0013-out-of-process-plugins.md) | Out-of-process plugin protocol | Proposed | — | Supplemented by [0015](0015-keyless-cosign-plugin-trust.md) |
| [0014](0014-no-linux-no-helling-plugin.md) | No Linux; no Helling plugin | Proposed | — | — |
| [0015](0015-keyless-cosign-plugin-trust.md) | Keyless Sigstore for plugin trust | Accepted | — | — |
| [0016](0016-secret-broker-order-and-cache.md) | Secret broker order + cache | Accepted | — | — |
| [0017](0017-keep-machines-toml-fleet-metadata.md) | Keep machines.toml fleet metadata | Accepted | — | — |
| [0018](0018-drop-mpm-for-brew-bundle.md) | Drop mpm; brew bundle is the single backend | Accepted | [0010](0010-native-brew-keep-mpm.md) | — |
| [0019](0019-cask-depends-on-backends.md) | Cask depends on chezmoi + mas | Accepted | — | — |
| [0020](0020-sparkle-plus-cask-hybrid-update.md) | Sparkle + cask hybrid updates | Accepted | — | — |
| [0021](0021-brew-vulns-replaces-advisory-service.md) | brew vulns replaces AdvisoryService | Accepted | — | — |
| [0022](0022-rejected-nix-mode.md) | Rejected Nix mode | Rejected | — | — |
| [0023](0023-containers-panel-detection.md) | Containers panel detection priority | Accepted | — | — |
| [0024](0024-mas-touch-id-privileged-helper.md) | mas Touch ID privileged helper | Accepted | — | — |
| [0025](0025-sparkle-delta-updates.md) | Sparkle delta updates | Accepted | — | — |
| [0026](0026-multi-machine-conflict-ux.md) | Multi-machine conflict UX | Accepted | — | — |
| [0027](0027-agent-tooling-bridges.md) | Project-scoped agent tooling bridges | Accepted | — | — |

---

> **Note on "Supplemented by"**: ADRs 0011 and 0013 remain valid as the
> abstract decisions (broker abstraction; out-of-process plugin host).
> 0015 and 0016 add implementation details for plugin trust and broker order.
