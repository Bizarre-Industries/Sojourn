# Repo layout — Sojourn app source

The repo holding Sojourn's source code. The user's data repo (their personal
dotfiles/packages) is documented separately at
[reference/repo-layout-user.md](repo-layout-user.md).

```
sojourn/
├── README.md
├── LICENSE                         # GPL-3.0-or-later (decisions/0004)
├── AGENTS.md                       # AI/contributor context
├── CLAUDE.md                       # legacy pointer to AGENTS.md
├── CONTRIBUTING.md
├── SECURITY.md                     # vuln disclosure policy (root convention)
├── CODE_OF_CONDUCT.md              # Contributor Covenant 2.1
├── MAINTAINERS.md
├── THIRDPARTY.md                   # 1-line pointer; source at docs/reference/third-party.md
├── CHANGELOG.md                    # keep-a-changelog 1.1
├── .gitleaks.toml                  # for sojourn's own CI
├── .github/
│   └── workflows/
│       ├── ci.yml                  # build + test + gitleaks
│       ├── notarize.yml            # signed DMG on tag
│       ├── codeql.yml              # weekly
│       └── docs-lint.yml           # markdown-link-check
├── Package.swift                   # SPM root (testing + CLI tools)
├── Sojourn.xcodeproj/              # primary build (xcodegen-generated)
├── project.yml                     # xcodegen spec
├── Sojourn/                        # app target
│   ├── App/
│   ├── Models/
│   ├── Services/
│   ├── Jobs/
│   ├── Scheduling/
│   ├── Sync/
│   ├── UI/
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   ├── bin/                    # gitleaks, age (re-signed in build)
│   │   └── data/
│   │       ├── applications/       # Mackup-derived registry, GPL-3
│   │       ├── dotfile_owners.toml
│   │       └── gitleaks.toml
│   ├── Sojourn.entitlements
│   └── Info.plist
├── SojournTests/                   # Swift Testing + XCTest
│   ├── Services/
│   ├── Sync/
│   └── Fixtures/
│       ├── mpm-installed.json      # golden files
│       ├── chezmoi-managed.json
│       └── gitleaks-report.json
├── SojournUITests/
├── scripts/
│   ├── sign.sh
│   ├── notarize.sh
│   ├── make-dmg.sh
│   └── update-registry.py          # refresh applications/ from upstream
└── docs/
    ├── README.md                   # Diátaxis index
    ├── start/                      # tutorials
    ├── how-to/                     # task-oriented guides
    ├── reference/                  # this directory
    ├── explain/                    # rationale
    ├── decisions/                  # ADRs
    ├── process/                    # contributor/maintainer churn
    ├── design/                     # visual artifacts
    ├── assets/                     # diagrams + screenshots
    └── redirects.toml              # CI link-check allowlist
```

For the file-level module breakdown of `Sojourn/`, see
[reference/modules.md](modules.md).
