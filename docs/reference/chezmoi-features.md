# chezmoi feature surface

Which chezmoi v2.70.x features Sojourn wraps, which it deliberately
doesn't, and why. Driven by audit
[process/audit-2026-04.md §2.2](../process/audit-2026-04.md#22-chezmoi-features-not-surfaced).
The backend invocation surface itself is in
[reference/backends/chezmoi.md](backends/chezmoi.md); this page is
the cross-reference index by chezmoi feature.

## Status legend

- **Wired** — `ChezmoiService` invokes this directly today.
- **Phase 12** — promised in the v1.x backend-feature-gap plan
  ([process/implementation-plan.md](../process/implementation-plan.md)
  Phase 12).
- **Phase 14** — covered by plugin / secret-broker work
  ([decisions/0011-secret-broker-abstraction.md](../decisions/0011-secret-broker-abstraction.md),
  [decisions/0013-out-of-process-plugins.md](../decisions/0013-out-of-process-plugins.md)).
- **Out of scope** — Sojourn deliberately doesn't surface; users invoke
  directly via `chezmoi <cmd>`.

## Read / apply path (already wired)

| Feature | Status | Notes |
|---|---|---|
| `chezmoi managed` | Wired | Lists tracked sources for the Dotfiles pane. |
| `chezmoi data` | Wired | Driver for template-render previews. |
| `chezmoi dump` / `dump-config` | Wired | Bootstrap diagnostics. |
| `chezmoi status` | Wired | Sync coordinator dirty-state probe. |
| `chezmoi diff` | Wired | Required reading before any apply. `--no-pager --color=false`. |
| `chezmoi apply` | Wired | Always preceded by `--dry-run`. Audit §2.2.3 swaps `--force` for `merge` on text dotfiles in Phase 12. |
| `chezmoi verify` | Wired | Post-apply integrity check. |
| `chezmoi execute-template` | Wired | Powers preview rendering in the per-file editor. |

## Externals + scripts (audit §2.2.1, §2.2.2)

| Feature | Status | Audit ID | Notes |
|---|---|---|---|
| `.chezmoiexternal.toml` | Phase 12 | 2.2.1 | First-class CRUD UX for archives, repos, and refresh periods. Reference: [reference/externals.md](externals.md). |
| `run_*` / `run_once_` / `run_onchange_` script lifecycle | Phase 12 | 2.2.2 | Idiomatic glue between chezmoi and mpm via `run_onchange_before_install-packages.sh.tmpl`. How-to: [how-to/dotfiles/add-run-script.md](../how-to/dotfiles/add-run-script.md). |
| `chezmoi update` (refreshes externals) | Phase 12 | 2.2.14 | Required to make 2.2.1 functional. |

## Merge + state (audit §2.2.3, §2.2.5–§2.2.9)

| Feature | Status | Audit ID | Notes |
|---|---|---|---|
| `chezmoi merge` | Phase 12 | 2.2.3 | Three-way merge for text dotfiles. Replaces `apply --force` for merge-eligible types. How-to: [how-to/sync/resolve-conflict.md](../how-to/sync/resolve-conflict.md). |
| `chezmoi unmanaged` | Phase 12 | 2.2.5 | Cross-referenced with `dotfile_owners.toml` to populate "Unmanaged" tab. |
| `chezmoi forget` | Phase 12 | 2.2.6 | Per-file demotion. How-to: [how-to/dotfiles/stop-tracking-file.md](../how-to/dotfiles/stop-tracking-file.md). |
| `chezmoi doctor` | Phase 12 | 2.2.7 | Embedded in [diagnostics export bundle](../how-to/diagnostics/export-bundle.md). |
| `chezmoi state` (script-state, entry-state) | Phase 12 | 2.2.8 | Force-rerun / skip-rerun controls in Diagnostics pane. |
| `promptBoolOnce` / `promptStringOnce` | Phase 12 | 2.2.9 | Replaces the Sojourn-side `.sojourn/machines/<id>.toml` per-machine override store (open question in [process/open-questions.md](../process/open-questions.md) §6). |

## Templating + secrets (audit §2.2.4, §2.2.10, §2.2.12)

| Feature | Status | Audit ID | Notes |
|---|---|---|---|
| Password-manager template functions (1Password, Bitwarden, Keychain, Vault, …) | Phase 14 | 2.2.4 | The 20+ provider native surface. Backed by [decisions/0011-secret-broker-abstraction.md](../decisions/0011-secret-broker-abstraction.md). Provider matrix: [reference/secret-brokers.md](secret-brokers.md). |
| `.chezmoitemplates/` partials | Phase 12 | 2.2.10 | Eliminates copy-paste in per-machine override blocks. |
| `encrypted_` + `.tmpl` combination | Phase 12 | 2.2.12 | Templated then encrypted. Per-machine encrypted secrets. |

## Source-dir + edit ergonomics (audit §2.2.11, §2.2.13)

| Feature | Status | Audit ID | Notes |
|---|---|---|---|
| `chezmoi edit --watch` | Out of scope | 2.2.11 | Power-user flow; users call directly. Sojourn does not wrap. |
| `chezmoi git` for source-dir commits | Phase 12 | 2.2.13 | Replaces direct `/usr/bin/git` calls inside the chezmoi source dir to respect chezmoi's internal locks. |

## Out-of-scope features

Sojourn does not wrap these — users invoke chezmoi directly:

- `chezmoi cd` (drops to a shell in the source dir).
- `chezmoi merge-all` (interactive; UX collides with Sojourn's guided
  conflict flow).
- `chezmoi archive` (ad-hoc snapshot; Sojourn's own backup flow covers).
- `chezmoi import` / `re-add --recursive` (bulk-track operations; users
  pick per-file via Sojourn's Dotfiles pane).

## See also

- [reference/backends/chezmoi.md](backends/chezmoi.md) — invocation
  surface (flags, JSON shapes, exit codes).
- [reference/externals.md](externals.md) — `.chezmoiexternal.toml`
  reference.
- [reference/secret-brokers.md](secret-brokers.md) — secret-broker
  abstraction and provider matrix.
- [process/audit-2026-04.md §2.2](../process/audit-2026-04.md#22-chezmoi-features-not-surfaced)
  — original gap analysis.
