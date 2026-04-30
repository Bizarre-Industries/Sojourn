# Settings reference

Every Sojourn setting, its default, its valid range, and where it
lives. Source of truth: `Sojourn/Config/{Debug,Release}.xcconfig` for
build-time flags + the `SettingsStore` actor for runtime user
preferences.

This page is the complete reference. v0.1 stub for shipped settings;
expand as `SettingsStore` lands new keys.

## Storage layout

| Surface | Where | Mutable | Synced |
|---|---|---|---|
| Build-time flags | `Sojourn/Config/*.xcconfig` | At build | No |
| User preferences | `~/Library/Preferences/app.bizarre.sojourn.plist` (via `UserDefaults`) | Yes | No (per-Mac) |
| Per-data-repo settings | `<data-repo>/.sojourn/settings.toml` | Yes | Yes (via git) |
| Secret material | macOS Keychain (service `app.bizarre.sojourn`) | Yes | No |

## Build-time flags (`xcconfig`)

| Key | Default | Notes |
|---|---|---|
| `SOJOURN_BUNDLE_IDENTIFIER` | `app.bizarre.sojourn` | Used in `Info.plist`, `OSLog` subsystem, `defaults` domain. |
| `SOJOURN_VERSION` | derived from git tag | SemVer `vMAJOR.MINOR.PATCH`. |
| `SOJOURN_BUILD` | derived from git commit -s count | Build number. |
| `SOJOURN_DEVELOPMENT_TEAM` | maintainer cert team ID | Code-signing identity. |
| `SOJOURN_OAUTH_CLIENT_ID` | maintainer's GitHub OAuth App | `client_id` only; no `client_secret`. |
| `SOJOURN_USE_SUBPROCESS_PACKAGE` | `YES` (Release) / `NO` (Debug) | Toggles between `swift-subprocess` and raw `Process`. |

## User preferences (UserDefaults / `SettingsStore`)

### Sync behaviour

| Key | Default | Range | Notes |
|---|---|---|---|
| `sync.cooldown_default_days` | `7` | `0`–`30` | Tier-A through Tier-D base cooldown. ADR-0003. |
| `sync.cooldown_npm_days` | `14` | `7`–`30` | Tier-E (global npm) override. |
| `sync.advisory_bypass_enabled` | `true` | bool | Allow OSV/GHSA to skip cooldown for known-vulnerable installed versions. |
| `sync.background_refresh_interval_hours` | `1` | `0.25`–`24` | `NSBackgroundActivityScheduler` cadence for `mpm outdated` + advisory fetch. |
| `sync.preview_default_layout` | `side-by-side` | `side-by-side` \| `unified` | Default diff layout. |
| `sync.confirm_before_apply` | `true` | bool | Require explicit confirm even after preview. |

### Secret scanning

| Key | Default | Range | Notes |
|---|---|---|---|
| `scan.lockout_seconds_high_confidence` | `5` | `0`–`30` | "Commit anyway" delay for verified-provider findings. ADR-0006. |
| `scan.allow_low_confidence_bypass` | `true` | bool | If false, even entropy-only findings need user click. |
| `scan.user_rules_path` | `<data-repo>/.gitleaks.toml` | path | Override file merged with bundled rules. |

### Cleanup

| Key | Default | Range | Notes |
|---|---|---|---|
| `cleanup.snapshot_retention_days` | `30` | `7`–`365` | `~/Library/Application Support/Sojourn/backups/` retention. |
| `cleanup.deletions_db_retention_days` | `30` | `7`–`365` | `deletions.db` row retention. |
| `cleanup.auto_run_in_background` | `false` | bool | Off by default; cleanup is user-initiated. |

### History

| Key | Default | Range | Notes |
|---|---|---|---|
| `history.retention_days` | `30` | `7`–`365` | `history.db` row retention. Open question — see [process/open-questions.md](../process/open-questions.md) §5. |
| `history.max_log_lines_per_job` | `10000` | `1000`–`100000` | Per-job log truncation. |

### UI

| Key | Default | Range | Notes |
|---|---|---|---|
| `ui.theme` | `system` | `system` \| `light` \| `dark` | Follows macOS appearance by default. |
| `ui.show_menu_bar_extra` | `true` | bool | Toggle the `MenuBarExtra` icon. |
| `ui.streaming_logs_default_open` | `false` | bool | Auto-open log console when a job starts. |

### Networking

| Key | Default | Range | Notes |
|---|---|---|---|
| `network.osv_endpoint` | `https://api.osv.dev` | URL | OSV advisory feed. |
| `network.timeout_seconds` | `30` | `5`–`300` | Default network timeout. |
| `network.subprocess_timeout_seconds` | `90` | `5`–`600` | Per-subprocess timeout. |

### Diagnostics

| Key | Default | Range | Notes |
|---|---|---|---|
| `diagnostics.bundle_includes_history_db` | `true` | bool | Copy `history.db` into the export bundle. |
| `diagnostics.bundle_includes_deletions_db` | `true` | bool | Copy `deletions.db` into the export bundle. |
| `diagnostics.redact_paths_in_export` | `true` | bool | Apply path-redaction rules ([explain/observability.md](../explain/observability.md)). |

## Per-data-repo settings (`.sojourn/settings.toml`)

Synced via git. Use sparingly — most settings should be per-Mac so
machines can disagree.

```toml
schema_version = "1"

[cooldown]
formulae_days = 7
casks_days    = 7

[scan]
custom_ignore = ["test/fixtures/**", "examples/*.example"]

[snapshot]
retention_days = 60
```

## Secret material (Keychain)

Service: `app.bizarre.sojourn`. Items:

| Account | Type | Notes |
|---|---|---|
| `github-device-flow-token` | OAuth token | Created by Device Flow opt-in; deleted on sign-out. |
| `age-recipient-public-key` | public key | Per-Mac identity for `age` encryption. |
| `age-identity-private-key` | private key | Owner-only ACL. Required on import. |

Sojourn never stores git credentials in this Keychain service — it
inherits the user's existing `git-credential-osxkeychain` items.

## See also

- [explain/design-philosophy.md](../explain/design-philosophy.md) —
  why settings prefer macOS-native storage.
- [explain/threat-model.md](../explain/threat-model.md) — secret
  material handling.
- [reference/cooldown-policy.md](cooldown-policy.md) — cooldown
  setting effects.
- [reference/cli.md](cli.md) — eventual CLI flag mapping.
