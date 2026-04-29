# Secret brokers

Sojourn delegates secret storage to per-provider brokers via chezmoi's
template-function surface. Decision recorded in
[decisions/0011-secret-broker-abstraction.md](../decisions/0011-secret-broker-abstraction.md).
Audit driver:
[process/audit-2026-04.md §2.6](../process/audit-2026-04.md#26-secret-broker-abstraction).

## Provider matrix

| Broker | Detection | chezmoi function | Sojourn priority |
|---|---|---|---|
| 1Password | `op` CLI | `onepasswordRead`, `onepassword`, `onepasswordItemFields`, `onepasswordDocument` | Primary |
| Bitwarden | `bw` CLI | `bitwarden`, `bitwardenFields` | Secondary |
| KeePassXC | `keepassxc-cli` | `keepassxc`, `keepassxcAttribute` | Secondary |
| pass | `pass` CLI | `pass` | Secondary |
| macOS Keychain | always present | `keyring` | Tertiary |
| Vault | `vault` CLI | `vault` | Tertiary |
| Doppler | `doppler` CLI | (template helper via `output`) | Tertiary |
| AWS Secrets Manager | `aws` CLI | (via `output`) | Tertiary |
| ejson / gopass | binary present | provider-specific | Tertiary |
| age | bundled | `decrypt` (encrypted_ files) | Fallback |

## Fallback ladder

For new secret references, Sojourn picks the first available provider in
order: 1Password → Bitwarden → Keychain → age. User can override per-file
via the "Insert secret reference" wizard.

`plaintext` is rejected by default. User must explicitly waive (per-file)
to commit a plaintext secret.

## 1Password mode trade-offs

| Mode | Pros | Cons |
|---|---|---|
| `account` (signed-in `op`) | Works for the dev's own machine | Network call per read; session timeout interrupts unattended apply |
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

When a secret rotates upstream (1Password vault edit), no Sojourn action
required — the next `chezmoi apply` re-reads the value via the template
function. age-encrypted secrets do require a rotation: re-encrypt with new
recipient, push.

## Audit / verification

Sojourn surfaces "Secret references resolved at last apply" in the
Diagnostics pane so the user can confirm which broker was hit per file.
