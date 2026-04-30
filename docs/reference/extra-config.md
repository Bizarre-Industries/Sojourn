# Extra config — taps, services, LaunchAgents, Login Items

Configuration that isn't a file in `~/.foo` and isn't a plist domain.
Audit driver:
[process/audit-2026-04.md §2.4](../process/audit-2026-04.md#24-configuration-that-isnt-files).

## Brew taps

`brew tap user/repo` adds a third-party formula source. Capture is via:

```
brew tap --json
```

(Audit §2.4.1 calls out: verify whether `mpm backup` already includes tap
lines; Brewfile does. If mpm omits, capture separately.)

Sojourn writes `taps.toml` alongside `packages.toml`:

```toml
[[tap]]
name = "homebrew/cask-fonts"

[[tap]]
name = "user/sojourn"
url = "https://github.com/user/homebrew-sojourn.git"  # optional, for non-default
```

On pull: `brew tap <name> [<url>]` for each.

## Brew services

`brew services list` returns running/loaded/stopped state for any formula
that ships a launchd plist (postgresql, redis, mysql, nginx, …).

Capture as JSON via `brew services list --json`. Sojourn writes
`services.toml`:

```toml
[[service]]
name = "postgresql@16"
status = "started"   # started | stopped | none
user = "current"     # current | sudo
```

On pull: `brew services start <name>` for each `started` row. Per-machine
gating allowed (audit §2.5).

UI: a Services subsection on the Homebrew detail page (audit §4.1.8) with
running / loaded / stopped state.

## LaunchAgents

`~/Library/LaunchAgents/*.plist` files run on user login. They are config,
not orphans (audit §2.4.3 — currently shown only as orphan candidates in
the Cleanup pane, which is wrong).

Sojourn syncs them as plain files via chezmoi but classifies them in
`dotfile_owners.toml` as **review tier** (auto-run on login is risky).

```toml
"Library/LaunchAgents" = { tool = "user-launchagents", source = "manual", classification = "review", sync = true }
```

UI: a "Background Items" subsection under Preferences (audit §4.1.9)
listing each LaunchAgent + its plist content + an enable/disable toggle.

## macOS Login Items

Apps the user has set to "Open at Login". Apple's public API is
`SMAppService` (macOS 13+). Sojourn captures the declarative list:

```toml
[[login_item]]
bundle_id = "com.apple.dock"        # always-on
hidden = false

[[login_item]]
bundle_id = "com.iconfactor.fantastical"
hidden = false
```

On pull: `SMAppService.mainApp.register()` per item. Subject to user
consent (the system prompts on first registration).

Audit §2.4.4 explicitly: use `SMAppService`, not legacy
`LSSharedFileList` (deprecated).

## Default app for extension

`duti` (Homebrew formula) prints/sets the default app per UTI:

```
duti -d com.apple.iwork.numbers       # show default for .numbers
duti -s com.microsoft.Excel xlsx all  # set
```

Audit §2.4.5: capture if `duti` is installed; otherwise document as
out-of-scope. Format:

```toml
[[default_app]]
extension = "md"
bundle_id = "com.microsoft.VSCode"
```

## Out of scope (documented)

| Concern | Why |
|---|---|
| `gh auth` tokens, 1Password CLI session | macOS Keychain — not Sojourn's lane. Audit §2.4.6. |
| LaunchServices DB (default-application bindings beyond `duti`) | `lsregister`-style capture; deferred to v2. Audit §2.4.7. |
| `crontab` | macOS deprecates in favour of launchd. Audit §2.4.9. |
| Tool version managers (mise, asdf, rustup, sdkman, volta, fnm, nvm) | Synced as **dotfile-classified** config files, not as service actors. See [reference/package-managers/](managers/). Audit §2.4.8. |
