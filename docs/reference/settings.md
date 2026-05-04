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
| `mpm.outdated_refresh_hours` | `1` | `0.25`–`24` | `NSBackgroundActivityScheduler` cadence for `mpm outdated`. |
| `network.osv_refresh_interval_hours` | `6` | `1`–`24` | OSV/GHSA advisory feed cadence. 6h cuts worst-case staleness vs the 24h in v0.1; see [reference/cooldown-policy.md](cooldown-policy.md) and [process/open-questions.md](../process/open-questions.md) §7 (closed). |
| `sync.preview_default_layout` | `side-by-side` | `side-by-side` \| `unified` | Default diff layout. |
| `sync.confirm_before_apply` | `true` | bool | Require explicit confirm even after preview. |

### Secret scanning

| Key | Default | Range | Notes |
|---|---|---|---|
| `scan.lockout_seconds_high_confidence` | `5` | `0`–`30` | "Commit anyway" delay for verified-provider findings. ADR-0006. |
| `scan.allow_low_confidence_bypass` | `true` | bool | If false, even entropy-only findings need user click. |
| `scan.user_rules_path` | `<data-repo>/.gitleaks.toml` | path | Override file merged with bundled rules. |

### Secret brokers

ADR-0011 + ADR-0016. Cache + timeout exist to keep `chezmoi apply` from
stalling on transient 1Password unreachability.

| Key | Default | Range | Notes |
|---|---|---|---|
| `secret_broker.read_timeout_seconds` | `5` | `1`–`60` | Per-secret timeout for broker reads (`op`, `bw`, `keyring`, etc.). |
| `secret_broker.cache_ttl_days` | `7` | `0`–`90` | Per-secret last-success cache TTL in Keychain. `0` disables cache. |
| `secret_broker.cache_fallback_enabled` | `true` | bool | On read timeout, serve cached value with banner. False = fail-closed. |
| `secret_broker.preferred` | (auto) | `1password` \| `keychain` \| `age` \| `prompt` | First-run prompt sets this. |

### Cleanup

| Key | Default | Range | Notes |
|---|---|---|---|
| `cleanup.snapshot_retention_days` | `30` | `7`–`365` | `~/Library/Application Support/Sojourn/backups/` retention. |
| `cleanup.deletions_db_retention_days` | `30` | `7`–`365` | `deletions.db` row retention. |
| `cleanup.auto_run_in_background` | `false` | bool | Off by default; cleanup is user-initiated. |

### History

ADR-aligned with [process/open-questions.md](../process/open-questions.md) §5
(closed): `history.db` is forensic data, not recoverability data, so the
retention horizon is the attack window (see
[explain/threat-model.md](../explain/threat-model.md) — xz-style multi-year
infiltration cases need 12–24 month lookback).

| Key | Default | Range | Notes |
|---|---|---|---|
| `history.retention_days_jobs` | `365` | `30`–`3650` | `jobs` row retention. ~700KB/year at 5 ops/day; trivial cost. |
| `history.retention_days_logs` | `90` | `7`–`365` | `job_logs` row retention. Heavier; capped further by `max_log_lines_per_job`. |
| `history.max_log_lines_per_job` | `10000` | `1000`–`100000` | Per-job log truncation. |
| `history.max_db_size_mb` | `500` | `100`–`5000` | Hard backstop. Oldest-first eviction across both tables when exceeded. |

### UI

| Key | Default | Range | Notes |
|---|---|---|---|
| `ui.theme` | `system` | `system` \| `light` \| `dark` | Follows macOS appearance by default. |
| `ui.show_menu_bar_extra` | `true` | bool | Toggle the `MenuBarExtra` icon. |
| `ui.streaming_logs_default_open` | `false` | bool | Auto-open log console when a job starts. |
| `installSource` | `unknown` | `unknown` \| `dmg` \| `cask` | Per-Mac install-source override in `SettingsStore`. `cask` suppresses Sparkle because Homebrew owns updates; `dmg` and `unknown` keep Sparkle enabled. |

### Networking

| Key | Default | Range | Notes |
|---|---|---|---|
| `network.osv_endpoint` | `https://api.osv.dev` | URL | OSV advisory query API (per-package lookups). |
| `network.osv_modified_id_base_url` | `https://storage.googleapis.com/osv-vulnerabilities` | URL | OSV per-ecosystem `modified_id.csv` delta-fetch base. |
| `network.timeout_seconds` | `30` | `5`–`300` | Default network timeout. |
| `network.subprocess_timeout_seconds` | `90` | `5`–`600` | Per-subprocess timeout. |

### Diagnostics

| Key | Default | Range | Notes |
|---|---|---|---|
| `diagnostics.bundle_includes_history_db` | `true` | bool | Copy `history.db` into the export bundle. With 365d job retention this carries useful debugging history; previous 30d default made the bundle near-useless for week-old reports. |
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

Companion service: `app.bizarre.sojourn.secret-cache` (per-secret broker
cache, ADR-0016). Owner-only ACL. Cache entries keyed by template-function
call site hash.

Sojourn never stores git credentials in this Keychain service — it
inherits the user's existing `git-credential-osxkeychain` items.

## See also

- [explain/design-philosophy.md](../explain/design-philosophy.md) —
  why settings prefer macOS-native storage.
- [explain/threat-model.md](../explain/threat-model.md) — secret
  material handling.
- [reference/cooldown-policy.md](cooldown-policy.md) — cooldown
  setting effects + OSV refresh mechanism.
- [reference/secret-brokers.md](secret-brokers.md) — broker order +
  cache details.
- [reference/cli.md](cli.md) — eventual CLI flag mapping.
