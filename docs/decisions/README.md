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
| [0009](0009-bundle-binary-policy.md) | Bundle gitleaks + age, not mpm + chezmoi | Accepted | — | — |
| [0010](0010-native-brew-keep-mpm.md) | Native brew/cask/mas; keep mpm for the rest | Proposed | — | — |
| [0011](0011-secret-broker-abstraction.md) | Secret broker abstraction (1Password primary, age fallback) | Proposed | — | Supplemented by [0016](0016-secret-broker-order-and-cache.md) |
| [0012](0012-cooperative-writer-lock.md) | Cooperative writer lock | Accepted | — | — |
| [0013](0013-out-of-process-plugins.md) | Out-of-process plugin protocol | Proposed | — | Supplemented by [0015](0015-keyless-cosign-plugin-trust.md) |
| [0014](0014-no-linux-no-helling-plugin.md) | No Linux; no Helling plugin | Proposed | — | — |
| [0015](0015-keyless-cosign-plugin-trust.md) | Keyless Sigstore as default for plugin trust; static-key fallback | Accepted | — | — |
| [0016](0016-secret-broker-order-and-cache.md) | Secret broker order: 1Password primary with cache + timeout, Keychain promoted, Bitwarden deferred | Accepted | — | — |
| [0017](0017-keep-machines-toml-fleet-metadata.md) | Keep `.sojourn/machines/<id>.toml`; coexist with chezmoi `promptOnce` | Accepted | — | — |

---

> **Note on "Supplemented by"**: ADRs 0011 and 0013 remain valid as the
> abstract decisions (broker abstraction; out-of-process plugin host).
> 0015 and 0016 add the implementation details that the maintainer
> deferred to [process/open-questions.md](../process/open-questions.md)
> §8 Q2 / Q3 — keyless cosign as default, broker order / cache / timeout.
> 0011 and 0013 will be promoted Proposed → Accepted when Phase 14 lands.
