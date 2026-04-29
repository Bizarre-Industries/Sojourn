# Moved — Sojourn architecture is now split across the docs tree

The 18-section `ARCHITECTURE.md` monolith has been split into focused pages
under [docs/reference/](reference/), [docs/explain/](explain/), and the ADR
log under [docs/decisions/](decisions/). The original file is preserved at
[docs/\_legacy_architecture.md](_legacy_architecture.md) for `git log
--follow` blame walks. The redirect will be removed in **v0.4**. See
[docs/process/DOCS_POLICY.md](process/DOCS_POLICY.md).

## Section map

| Old §                      | Old anchor                                                                 | New home                                                                                                                                                         |
| -------------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| §1 Codename                | `#1-code-name-selection-and-rationale`                                     | [explain/codename.md](explain/codename.md)                                                                                                                       |
| §2 Product summary         | `#2-product-summary`                                                       | [explain/product-overview.md](explain/product-overview.md)                                                                                                       |
| §3 Competitive landscape   | `#3-competitive-landscape-findings`                                        | [explain/competitive-landscape.md](explain/competitive-landscape.md)                                                                                             |
| §4 High-level architecture | `#4-high-level-architecture`                                               | [reference/architecture.md](reference/architecture.md)                                                                                                           |
| §5.1 mpm                   | `#51-mpm-v630-python-based-pyinstaller-frozen-standalone-binary-available` | [reference/backends/mpm.md](reference/backends/mpm.md)                                                                                                           |
| §5.2 chezmoi               | `#52-chezmoi-v2702-mit-single-static-go-binary`                            | [reference/backends/chezmoi.md](reference/backends/chezmoi.md)                                                                                                   |
| §5.3 gitleaks              | `#53-secret-scanning-gitleaks-bundled`                                     | [reference/backends/gitleaks.md](reference/backends/gitleaks.md)                                                                                                 |
| §5.4 git                   | `#54-git-shell-out-to-usrbingit`                                           | [reference/backends/git.md](reference/backends/git.md)                                                                                                           |
| §6 Sync model              | `#6-sync-model-spec`                                                       | [reference/sync-model.md](reference/sync-model.md)                                                                                                               |
| §7 Cooldown                | `#7-auto-update-safety-model`                                              | [reference/cooldown-policy.md](reference/cooldown-policy.md)                                                                                                     |
| §8 Plist sync              | `#8-plist-app-preference-sync-strategy`                                    | [reference/preference-sync.md](reference/preference-sync.md) + [explain/why-no-symlink-prefs.md](explain/why-no-symlink-prefs.md)                                |
| §9 Bootstrap               | `#9-dependency-bootstrap-flow`                                             | [reference/bootstrap-flow.md](reference/bootstrap-flow.md)                                                                                                       |
| §10 Cleanup                | `#10-dotfile-cleanup-cruft-detection`                                      | [reference/cleanup.md](reference/cleanup.md)                                                                                                                     |
| §11 SwiftUI structure      | `#11-swiftui-app-structure`                                                | [reference/modules.md](reference/modules.md) + [explain/state-management.md](explain/state-management.md) + [decisions/0005-no-tca.md](decisions/0005-no-tca.md) |
| §12 Repo structure         | `#12-repo-structure`                                                       | [reference/repo-layout-app.md](reference/repo-layout-app.md) + [reference/repo-layout-user.md](reference/repo-layout-user.md)                                    |
| §13 Licensing decision     | `#13-licensing-decision`                                                   | [reference/licensing.md](reference/licensing.md) + [decisions/0004-gpl-3-or-later.md](decisions/0004-gpl-3-or-later.md)                                          |
| §14 Risks                  | `#14-risks-and-unknowns`                                                   | [explain/risks.md](explain/risks.md)                                                                                                                             |
| §15 v1 scope cut           | `#15-proposed-v1-scope-cut`                                                | [process/implementation-plan.md](process/implementation-plan.md) "Out of scope" + [explain/future-work.md](explain/future-work.md)                               |
| §16 CLAUDE.md              | `#16-claudemd-repo-root`                                                   | repo root [CLAUDE.md](../CLAUDE.md) (and [AGENTS.md](../AGENTS.md))                                                                                              |
| §17 Testing                | `#17-testing`                                                              | [reference/testing.md](reference/testing.md)                                                                                                                     |
| §18 Observability          | `#18-observability`                                                        | [reference/observability.md](reference/observability.md)                                                                                                         |

## Where to start

Most readers want one of:

- **Top-down system view** → [reference/architecture.md](reference/architecture.md)
- **Module breakdown** → [reference/modules.md](reference/modules.md)
- **Why we made the load-bearing decisions** → [decisions/README.md](decisions/README.md)
- **What the audit found and what's deferred** → [process/audit-2026-04.md](process/audit-2026-04.md)
- **Phased implementation plan** → [process/implementation-plan.md](process/implementation-plan.md)

The full Diátaxis index is at [docs/README.md](README.md).
