# Keyboard shortcuts

Stub; v0.1 ships a minimal shortcut set. Audit
[§4.2.16](../process/audit-2026-04.md) flagged this as a gap. This
page reserves the URL and lists the shortcuts shipped + planned.

## Shipped (v0.1)

| Shortcut | Action | Where |
|---|---|---|
| `⌘N` | Open onboarding flow for a new repo | Main window |
| `⌘O` | Connect existing repo | Main window |
| `⌘,` | Open Settings | Main window |
| `⌘W` | Close active window | Standard macOS |
| `⌘Q` | Quit Sojourn | Standard macOS |
| `⌘1` … `⌘6` | Switch to Sidebar pane 1–6 | Main window |
| `⇧⌘P` | Push (after preview) | Push/pull bar |
| `⇧⌘L` | Pull (after preview) | Push/pull bar |
| `⌘⇧S` | Sync now (full pull + push when safe) | Main window |
| `⌘.` | Cancel running job | Job toolbar |
| `⌘L` | Open log console for the active job | Standard |
| `⌘F` | Find within current pane | Standard |
| `⌘⌫` | Move selected item to Trash (Cleanup pane only) | Cleanup pane |

## Planned (later releases)

These are reserved but not yet bound:

| Shortcut | Action | Notes |
|---|---|---|
| `⌘E` | Edit selected dotfile in `chezmoi edit` | Phase 12 — `chezmoi edit --watch` integration. |
| `⌘D` | Diff selected file | Phase 12. |
| `⌘R` | Refresh status | Phase 6 polish. |
| `⌘⇧B` | Show backups list | Phase 9 — Cleanup pane. |
| `⌘⇧K` | Take writer lock | Phase 6 — currently chip-only. |

## Conflict-avoidance

These standard macOS shortcuts must remain bound to the system action
in every pane:

- `⌘C` / `⌘V` / `⌘X` — copy/paste/cut.
- `⌘Z` / `⇧⌘Z` — undo/redo (within text fields only; no global undo).
- `⌘A` — select all.
- `⌘F` — find (per-pane scope).
- `⌘?` — Help menu.

## Shortcut-discoverability

Audit §4.2.16 also flagged the lack of in-app shortcut hints. v0.1
relies on the macOS Help menu's automatic shortcut listing. A future
release adds a discoverability sheet (`⌘?` opens cheatsheet).

## See also

- [process/audit-2026-04.md §4.2.16](../process/audit-2026-04.md) —
  original gap.
- [explain/design-philosophy.md](../explain/design-philosophy.md) —
  why Sojourn uses macOS-native shortcut conventions.
