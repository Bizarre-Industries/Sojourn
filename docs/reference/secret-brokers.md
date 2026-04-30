# Secret brokers

Sojourn delegates secret storage to per-provider brokers via chezmoi's
template-function surface. Decision recorded in
[decisions/0011-secret-broker-abstraction.md](../decisions/0011-secret-broker-abstraction.md).
Order, cache, and timeout in
[decisions/0016-secret-broker-order-and-cache.md](../decisions/0016-secret-broker-order-and-cache.md).
Audit driver:
[process/audit-2026-04.md §2.6](../process/audit-2026-04.md#26-secret-broker-abstraction).

## Provider matrix (v1)

| Broker | Detection | chezmoi function | Sojourn priority | Ships in |
|---|---|---|---|---|
| 1Password | `op` CLI | `onepasswordRead`, `onepassword`, `onepasswordItemFields`, `onepasswordDocument` | Primary | v1 |
| macOS Keychain | always present | `keyring` | Secondary | v1 |
| age | bundled | `decrypt` (encrypted_ files) | Fallback | v1 |
| Bitwarden | `bw` CLI | `bitwarden`, `bitwardenFields` | — | **v1.1 (deferred)** |
| KeePassXC | `keepassxc-cli` | `keepassxc`, `keepassxcAttribute` | — | v1.1+ |
| pass | `pass` CLI | `pass` | — | v1.1+ |
| Vault | `vault` CLI | `vault` | — | v1.1+ |
| Doppler | `doppler` CLI | (template helper via `output`) | — | v1.1+ |
| AWS Secrets Manager | `aws` CLI | (via `output`) | — | v1.1+ |
| ejson / gopass | binary present | provider-specific | — | v1.1+ |

Bitwarden is **deferred to v1.1** per ADR-0016. It has the same
network + session properties as 1Password, and requires an extra CLI
install — strictly worse than Keychain in the apply hot-path. Kept on
the matrix because the protocol surface accommodates it; the work to
re-introduce in v1.1 is one actor + UI enable.

## Fallback ladder (v1)

For new secret references, Sojourn picks the first available provider in
order: **1Password → Keychain → age**. User can override per-file via the
"Insert secret reference" wizard.

If multiple brokers are detected at first-run bootstrap, Sojourn
**prompts** for a default rather than auto-picking
(`secret_broker.preferred` setting). This is the explicit-choice posture
ADR-0011 calls for; ADR-0016 codifies it in implementation.

`plaintext` is rejected by default. User must explicitly waive (per-file)
to commit a plaintext secret. Override prompts a gitleaks rescan
before commit and a 5s lockout per the
[reference/cooldown-policy.md](cooldown-policy.md) lockout pattern.

## Apply-path failure mode and the cache

`op` is in the hot path of every `chezmoi apply` because every template
function runs on every apply, and every pull runs apply. In `account`
mode (recommended default below), `op` does a network call to 1Password
servers and respects session timeouts — so flaky network, 1Password API
blips, and timed-out `op` sessions all stall pull.

ADR-0016's mitigation:

- Per-secret last-success cache in macOS Keychain (service
  `app.bizarre.sojourn.secret-cache`). Owner-only ACL; cache entries
  keyed by template-function call site hash.
- `secret_broker.read_timeout_seconds` (default 5).
- On `op` timeout / outage, fall back to cached value with a visible
  banner "1Password unreachable; using cached secret from <date>."
- Fail-closed only if no cache exists.
- Cache TTL: `secret_broker.cache_ttl_days` (default 7). Manual flush
  in Settings → Secrets.
- Banner persists in the menu bar status icon while the fallback is
  active; clears on next successful broker read.

Settings: see [reference/settings.md](settings.md) "Secret brokers".

## 1Password mode trade-offs

| Mode | Pros | Cons |
|---|---|---|
| `account` (signed-in `op`) | Works for the dev's own machine | Network call per read; session timeout interrupts unattended apply (mitigated by cache) |
| `connect` (1Password Connect server) | Server-side; no per-read timeout | Requires self-hosted Connect |
| `service` (Service Account) | No interactive auth | Token rotation overhead |

Sojourn recommends `account` mode for individual users; `service` for CI;
`connect` for teams.

## Common configs that should use a broker

When the broker ladder resolves to 1Password, Sojourn proposes `op://`
references for these file types by default:

| File | Provider key shape |
|---|---|
| `~/.aws/credentials` | `op://Vault/AWS/access_key_id` + `secret_access_key` |
| `~/.npmrc` | `op://Vault/npm/_authToken` |
| `~/.pypirc` | `op://Vault/PyPI/password` |
| `~/.docker/config.json` | `op://Vault/Docker/auths.<host>.auth` |
| `~/.kube/config` | `op://Vault/Kube/<context>` |
| `~/.cargo/credentials.toml` | `op://Vault/crates.io/token` |

User can override per-file. The audit
[process/audit-2026-04.md §2.6.5](../process/audit-2026-04.md#26-secret-broker-abstraction)
calls these out as the highest-leverage migration targets.

## Rotation flow

When a secret rotates upstream (1Password vault edit), the Sojourn cache
holds the old value until either (a) cache TTL expires, or (b) the user
manually flushes in Settings → Secrets. Cache flush forces a fresh
broker read on next apply.

age-encrypted secrets do require a separate rotation: re-encrypt with new
recipient, push.

## Audit / verification

Sojourn surfaces "Secret references resolved at last apply" in the
Diagnostics pane so the user can confirm which broker was hit per file
(live read vs cache fallback explicitly distinguished).
