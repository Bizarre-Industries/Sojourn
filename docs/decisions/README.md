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
| [0011](0011-secret-broker-abstraction.md) | Secret broker abstraction (1Password primary, age fallback) | Proposed | — | — |
| [0012](0012-cooperative-writer-lock.md) | Cooperative writer lock | Accepted | — | — |
| [0013](0013-out-of-process-plugins.md) | Out-of-process plugin protocol | Proposed | — | — |
| [0014](0014-no-linux-no-helling-plugin.md) | No Linux; no Helling plugin | Proposed | — | — |

## Status meanings

- **Proposed** — decision drafted; code not yet merged. Cite the
  [implementation plan](../process/implementation-plan.md) phase that promotes
  it to Accepted.
- **Accepted** — decision implemented; this is the current state.
- **Superseded by NNNN** — replaced by a later ADR. The historical reasoning
  stays intact in this file.
- **Deprecated** — no longer applies; nothing replaces it.

## Adding a new ADR

1. Pick the next number (`max(current) + 1`). Never reuse a number.
2. `cp _template.md NNNN-kebab-case.md`.
3. Fill in Context, Decision, Consequences, Alternatives.
4. Set status:
   - `Proposed` if implementation lands later (cite the IMPL_PLAN phase).
   - `Accepted` if implementation lands in the same PR.
5. Add a row above.
6. Cross-link from the source-content reference page.
