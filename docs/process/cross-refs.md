# Cross-references — ADRs ↔ council logs ↔ lessons.md

Hand-maintained index linking each architectural decision to its
deliberation log + the empirical learnings that resulted. Updated
on every council fire + every lessons.md append.

## Why this exists

ADRs document **what** was decided + **why at the time**. Council
logs document **how the decision was stress-tested** before commit.
`lessons.md` documents **what we learned afterward**.

These three files individually are useful; cross-linked they form a
review chain that lets future-you (or a new contributor) trace any
architectural choice from rationale → adversarial review → empirical
outcome.

## Index

| ADR | Title | Council log | lessons.md anchors |
| --- | --- | --- | --- |
| [0001](../decisions/0001-ipc-not-linking.md) | IPC, not linking | — (pre-council) | — |
| [0002](../decisions/0002-defaults-import-not-symlinks.md) | defaults import, not symlinks | — | "chezmoi `defaults` dotfile pattern" |
| [0006](../decisions/0006-gitleaks-bundled.md) | gitleaks bundled | — | — |
| [0007](../decisions/0007-shell-out-to-git.md) | shell out to git | — | — |
| [0008](../decisions/0008-no-curl-bash-for-brew.md) | no curl-bash for brew | — | "brew formula installs without sudo" |
| [0010](../decisions/0010-mpm-as-meta-cli.md) | mpm as meta-CLI | superseded by 0018 | "Drop mpm for brew bundle" |
| [0011](../decisions/0011-secret-broker-abstraction.md) | secret broker abstraction | — | — |
| [0012](../decisions/0012-cooperative-writer-lock.md) | cooperative writer lock | — | — |
| [0014](../decisions/0014-no-linux-no-helling-plugin.md) | no Linux, no Helling plugin | — | — |
| [0015](../decisions/0015-keyless-cosign-plugin-trust.md) | keyless cosign plugin trust | — | — |
| [0016](../decisions/0016-secret-broker-order-and-cache.md) | secret broker order + cache | — | — |
| [0017](../decisions/0017-keep-machines-toml-fleet-metadata.md) | keep machines.toml fleet metadata | — | — |
| [0018](../decisions/0018-brew-bundle-as-single-backend.md) | brew bundle as single backend | [2026-05-01-v0.2-adr-batch](../../.claude/council-logs/2026-05-01-v0.2-adr-batch.md) | "Drop mpm for brew bundle" |
| [0019](../decisions/0019-bundle-brew-formula.md) | bundle brew formula | [2026-05-01-v0.2-adr-batch](../../.claude/council-logs/2026-05-01-v0.2-adr-batch.md) | — |
| [0020](../decisions/0020-sparkle-plus-cask-hybrid-update.md) | Sparkle + cask hybrid update | [2026-05-01-v0.2-adr-batch](../../.claude/council-logs/2026-05-01-v0.2-adr-batch.md) | "Cask Cookbook missing fields" |
| [0021](../decisions/0021-brew-vulns-replaces-advisory-service.md) | brew vulns replaces AdvisoryService | [2026-05-01-v0.2-adr-batch](../../.claude/council-logs/2026-05-01-v0.2-adr-batch.md) | — |
| [0022](../decisions/0022-rejected-nix-mode.md) | REJECTED Nix mode | [2026-05-01-v0.2-adr-batch](../../.claude/council-logs/2026-05-01-v0.2-adr-batch.md) | "Drop Nix as a Phase 2 mode" |
| [0023](../decisions/0023-containers-panel-detection.md) | Containers panel detection | [2026-05-03-v0.3-adr-batch](../../.claude/council-logs/2026-05-03-v0.3-adr-batch.md) | — (pending v0.4 if write actions added) |
| [0024](../decisions/0024-mas-touch-id-privileged-helper.md) | mas Touch-ID privileged helper | [2026-05-03-v0.3-adr-batch](../../.claude/council-logs/2026-05-03-v0.3-adr-batch.md) | "mas requires sudo on macOS 14.8.2+ / 15.7.2+ / 26.1+" |
| [0025](../decisions/0025-sparkle-delta-updates.md) | Sparkle delta updates | [2026-05-03-v0.3-adr-batch](../../.claude/council-logs/2026-05-03-v0.3-adr-batch.md), [2026-05-04-stage6-sparkle-delta](../../.claude/council-logs/2026-05-04-stage6-sparkle-delta.md) | — (pending v0.3.0 corrupt-delta VM smoke) |
| [0026](../decisions/0026-multi-machine-conflict-ux.md) | Multi-machine refuse-and-show-diff | [2026-05-03-v0.3-adr-batch](../../.claude/council-logs/2026-05-03-v0.3-adr-batch.md), [2026-05-04-stage5-conflict-resolver](../../.claude/council-logs/2026-05-04-stage5-conflict-resolver.md) | — |
| [0027](../decisions/0027-agent-tooling-bridges.md) | Project-scoped agent tooling bridges | [2026-05-04-release-signing-and-agent-tooling](../../.codex/council-logs/2026-05-04-release-signing-and-agent-tooling.md) | "Global peer-agent MCP bridges must not point at another repo" |

## Council logs without an ADR

Some council fires don't decide on an ADR — they deliberate on a
risky implementation choice (release pipeline, CI workflow, signing
flow). Indexed separately:

| Council log | Subject | Outcome |
| --- | --- | --- |
| [2026-05-01-notarize-publish-direct-push](../../.claude/council-logs/2026-05-01-notarize-publish-direct-push.md) | Cask publish: direct push vs `bump-cask-pr` | direct push (after PAT-scope blocker) |

## How to maintain this file

When a new ADR lands → add a row to "Index" with the ADR number,
title, council log slug (if council fired), and lessons.md anchor
(quote the topic header).

When a new council log lands → if it's an implementation deliberation
(not ADR-driven), add a row to "Council logs without an ADR".

When a new `lessons.md` entry lands → if it relates back to a
prior ADR's empirical outcome, update the matching ADR row's
`lessons.md anchors` cell.

Hand-maintained, not auto-generated. The cost is one row edit per
new ADR / council log / lessons entry. The value is a navigable
audit trail when future-you (or a new contributor, or a council
member firing on a v0.5 ADR) needs to understand why v0.2 made the
decisions it did.

## Anti-pattern: bulk regeneration

Don't try to regenerate this file from scratch by parsing all ADRs.
Cross-references are inherently human-curated — they capture
"this lesson informed that decision" in a way that grep can't infer.
If a row is wrong, fix that row. If a row is missing, add that row.
