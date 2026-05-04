---
name: Repro drift
about: Two machines diverged at the same git SHA — runtime behaviour disagrees
title: 'repro-drift: <one-line description>'
labels: ['repro-drift']
assignees: []
---

> **What this is.** Sojourn's promise: the same `Brewfile.common` +
> `Brewfile.<host>` + chezmoi state on two machines produces equivalent
> runtime behaviour. When that breaks — same git SHA, divergent results —
> file here. Two such reports filed against your data repo within
> 30 days fires the
> [ADR-0022](/docs/decisions/0022-rejected-nix-mode.md) flip-condition
> #2 and triggers a new ADR proposing Nix as an alternative backend.
>
> File this template against the **data/dotfiles repo** Sojourn syncs
> against — drift is observed there, not in Sojourn's source tree.
> Copy this file into your repo's `.github/ISSUE_TEMPLATE/` once via
> Sojourn's "setup new dotfiles repo" flow.

## Both machines

| | Machine A | Machine B |
|---|---|---|
| `hostname` | | |
| macOS version | | |
| CPU (Apple Silicon / Intel) | | |
| Sojourn version | | |
| `git rev-parse HEAD` of dotfiles repo | | |
| `chezmoi state dump | sha256sum` | | |
| Brewfile.common SHA-256 | | |

The git SHAs **must** match (otherwise this is normal divergence, not
repro drift).

## What diverged

Describe the symptom — the runtime behaviour that disagrees between
the two machines despite identical declarative state.

```
# Output from machine A
$ <command>
<output>

# Output from machine B
$ <command>
<output>
```

## Diff investigation

What did you check, what was equal, what wasn't?

- [ ] `brew bundle check --file=Brewfile.common` agrees on both
- [ ] `chezmoi diff` is empty on both
- [ ] `defaults read <suspect-domain>` agrees on both
- [ ] `mas list | sort` agrees on both
- [ ] `xcode-select -p` agrees on both
- [ ] System-level config not in scope of any of Sojourn's surfaces

## Hypothesis

Where do you think the drift comes from?
