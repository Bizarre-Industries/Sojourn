# Sojourn — Design handoff

This directory contains the design specification that drives Sojourn's
visual surface. The handoff is a Claude Design (claude.ai/design) export
covering identity, app icon, 23 SwiftUI artboards, and the macOS Tahoe
Liquid Glass × Bizarre Industries treatment.

## Layout

```
docs/design/
├── README.md                          ← this file
└── handoff/
    ├── sojourn-design.tgz             ← tracked archive (canonical source)
    └── extracted/                     ← gitignored extract (build artifact)
        └── sojourn/
            ├── README.md              ← bundle README (read first)
            ├── chats/                 ← 2 transcripts of design intent
            └── project/               ← styles, JSX components, fonts, assets
```

## Extracting

```sh
make extract-design
# or:
tar -xf docs/design/handoff/sojourn-design.tgz \
    -C docs/design/handoff/extracted
```

## Source-of-truth files

After extracting, work from `docs/design/handoff/extracted/sojourn/`:

| Artifact | Path | Purpose |
|----------|------|---------|
| Tokens | `project/styles.css` | Brand colors, typography, radii, spacing |
| Liquid Glass | `project/liquid-glass.css` | Tahoe glass primitives (specular, blur, refraction) |
| Carry overview | `project/carry.jsx` | Landing pane (`CarryOverviewScreen`) |
| Main panes | `project/screens.jsx` | Packages / Dotfiles / Preferences / History / Machines / Cleanup / Settings / Secrets |
| Onboard / Conflicts / Diagnostics | `project/extras.jsx` | First-run + sync conflict shapes + diagnostics |
| Power surfaces (1) | `project/power.jsx` | Job Inspector / Schedule / Age / Chezmoi templates / Gitleaks rules |
| Power surfaces (2) | `project/power2.jsx` | Authorization / Manager detail / Backups / Defaults Discover / Repo Setup |
| Bootstrap + sheets | `project/specials.jsx` | Bootstrap state machine, Push/Pull sheets, Menu bar extra |
| Architecture | `project/architecture.jsx` | 4-layer reference card |
| Logo / icon | `project/sojourn-logo.jsx`, `project/app-icon.jsx` | Stencil S mark + 5-mode app icon |
| Window chrome | `project/chrome.jsx` | Sidebar, toolbar, eyebrow, frame |
| Icon set | `project/icons.jsx` | Inline SVG icon set used across panes |

## Design intent

Read both chat transcripts before touching pane code. They explain *why*
the design landed where it did:

- `chats/chat1.md` — initial design pass; user pushback ("doesn't even
  use Liquid Glass"); rewrite to authentic Tahoe glass.
- `chats/chat2.md` — Carry promoted to lead; Sync demoted; 10 Power
  surfaces added; identity finalized; light-mode lime-readability fix.

## Implementation contract

The Swift translation lives in `Sojourn/UI/`:

- Tokens: `Sojourn/UI/Tokens/{Color,Font,Radii,Spacing}+Sojourn.swift`
- Liquid Glass: `Sojourn/UI/Components/LiquidGlass.swift`
- Atoms: `Sojourn/UI/Components/Atoms.swift`
- Sidebar: `Sojourn/UI/Components/Sidebar.swift`
- Panes: `Sojourn/UI/Panes/<section>/<Pane>.swift`
- Sheets: `Sojourn/UI/Sheets/<Sheet>.swift`

Match visual output, not internal JSX structure.
