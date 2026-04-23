# Applications registry

This directory holds per-application preference-sync definitions in TOML. Each file describes one app: its bundle identifier, the paths it stores preferences at, and the classification Sojourn uses for sync (see [docs/ARCHITECTURE.md §8](../../../../docs/ARCHITECTURE.md#8-plist-app-preference-sync-strategy)).

## Origin and license

The registry is **derived from Mackup** (https://github.com/lra/mackup), GPL-3.0, `applications/` directory. Sojourn forks and re-classifies each entry because a significant fraction of Mackup's original paths will trip `cfprefsd` or Containers TCC on Sonoma and later (see the WARNING banner in Mackup's own README).

Sojourn's fork stays GPL-3.0-or-later. Upstream attribution is kept in each file header:

```toml
# Derived from lra/mackup @ <SHA>:applications/<file>.cfg
# Re-classified for Sojourn per docs/ARCHITECTURE.md §8.
```

## Schema

```toml
[app]
id = "com.googlecode.iterm2"
display_name = "iTerm2"

[[preferences]]
domain = "com.googlecode.iterm2"
class = "unsandboxed_plist"          # plain_dotfile | unsandboxed_plist | sandboxed_plist | application_support_blob
path = "~/Library/Preferences/com.googlecode.iterm2.plist"

[[preferences]]
domain = "com.googlecode.iterm2"
class = "application_support_blob"
path = "~/Library/Application Support/iTerm2/DynamicProfiles"
```

## Maintenance

The `scripts/update-registry.py` helper pulls the current Mackup `applications/`, converts each `.cfg` to TOML, and re-classifies per Sojourn's taxonomy. Human review required before merge; the helper flags entries that need hand classification.
