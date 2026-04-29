# Repo layout — user's data repo

The repo Sojourn manages on the user's behalf. Sojourn proposes this
structure on first push. User's remote, user's name. The Sojourn app source
repo is documented separately at
[reference/repo-layout-app.md](repo-layout-app.md).

```
my-mac/
├── packages.toml                   # mpm backup output (TOML)
├── dotfiles/                       # chezmoi source dir
│   ├── dot_zshrc.tmpl
│   ├── dot_gitconfig.tmpl
│   ├── private_dot_ssh/
│   │   └── encrypted_id_ed25519.age
│   ├── .chezmoidata.toml
│   └── .chezmoiignore
├── preferences/                    # one XML plist per tracked domain
│   ├── com.googlecode.iterm2.plist
│   ├── com.apple.dock.plist
│   └── ...
├── .sojourn/
│   ├── machines/
│   │   ├── work-mbp.toml
│   │   └── personal-mini.toml
│   ├── active.toml                 # current writer (cooperative lock)
│   ├── version.toml                # repo schema version (migrate on bump)
│   └── backups/                    # pre-operation snapshots, 30d retention
├── .gitleaks.toml                  # user's allowlist
├── .gitignore
└── README.md                       # generated; "this repo is managed by Sojourn"
```

## Notes

- `packages.toml` at root — matches mpm's `backup` output 1:1.
- `dotfiles/` is chezmoi's source dir — chezmoi handles the `dot_` /
  `private_` / `encrypted_` / `.tmpl` naming conventions.
- `preferences/` is XML plist (converted via `plutil`) per domain — **not**
  symlinked, not live. See
  [decisions/0002-no-symlink-preferences.md](../decisions/0002-no-symlink-preferences.md).
- `.sojourn/` namespaces Sojourn-specific metadata so it's grouped and easy
  to migrate.
- `active.toml` is the cooperative writer lock (see
  [reference/sync-model.md](sync-model.md)).
- `version.toml` carries a schema version for future migrations.
- `backups/` holds rollback snapshots, 30-day retention.
- `.gitleaks.toml` lets per-repo allowlists travel with the repo.

## File format specs

Detailed schemas for each file live under
[reference/file-formats/](file-formats/) — `packages-toml.md`,
`machines-toml.md`, `active-toml.md`, `version-toml.md`, `deletions-db.md`.
