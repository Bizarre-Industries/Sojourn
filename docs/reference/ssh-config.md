# SSH config

`~/.ssh/config` is technically a plain dotfile, but the rest of the SSH
surface needs a coherent policy. Audit driver:
[process/audit-2026-04.md §2.5](../process/audit-2026-04.md#25-ssh-specific-gaps).

## File-by-file policy

| File | Sync? | Notes |
|---|---|---|
| `~/.ssh/config` | Yes (chezmoi) | Plain text; templates fine. |
| `~/.ssh/conf.d/*` | Yes (chezmoi) | Use `Include conf.d/*` in main config; per-host blocks. |
| `~/.ssh/known_hosts` | **No** | Host-volatile fingerprint churn. Default `.chezmoiignore`. |
| `~/.ssh/known_hosts.old` | No | Same as above. |
| `~/.ssh/authorized_keys` | No | Out-of-scope for the dev's own machine. `sync = false` in `dotfile_owners.toml`. |
| `~/.ssh/id_*` (private keys) | No (default) | Encryption-at-rest required if the user opts in; use `encrypted_` + age or `op://`. |
| `~/.ssh/id_*.pub` | Yes | Public; safe. |
| `~/.ssh/agent.sock`, sockets | No | Runtime artifacts. |

## `Include conf.d/*` scaffold

Sojourn writes a default `dot_ssh/config.tmpl` on first push:

```
# Managed by Sojourn — edits here may be overwritten.
# Per-host overrides live in ~/.ssh/conf.d/*

Include conf.d/*

# Global defaults
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentitiesOnly yes
{{ if eq .chezmoi.os "darwin" -}}
{{ if .features.use_1password_ssh -}}
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
{{ else -}}
    # Default macOS ssh-agent
{{ end -}}
{{ end }}
```

## 1Password SSH agent

The socket path on macOS:

```
~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

This path differs on Linux. Sojourn templates the `IdentityAgent` line
with `.chezmoi.os` so a single template works across platforms (relevant
for the future Linux conversation; see
[decisions/0014-no-linux-no-helling-plugin.md](../decisions/0014-no-linux-no-helling-plugin.md)).

## SSH commit signing

Per-machine because the key path differs across Macs. Sojourn templates:

```
[user]
    signingkey = {{ .signing.ssh_key_path }}
[gpg]
    format = ssh
[gpg "ssh"]
    allowedSignersFile = {{ .signing.allowed_signers_path }}
[commit]
    gpgsign = true
```

The `signing.ssh_key_path` and `signing.allowed_signers_path` values come
from `.chezmoidata.toml`, edited via the Repo setup pane. UI: a "Signing
key picker" that lists `~/.ssh/id_*.pub` + `op://` references.

## known_hosts

Default `.chezmoiignore` boilerplate (audit §2.5.1):

```
.ssh/known_hosts
.ssh/known_hosts.old
.ssh/agent.sock
.ssh/master-*
```

This is written on first push so users don't accidentally commit their
fingerprint history (which is a privacy leak — every host they SSH'd to).

## Security model

- Private keys never sync without explicit user opt-in + encryption.
- `authorized_keys` is host-managed; not Sojourn's lane.
- TPM/secure-enclave-backed keys (Secretive, ssh-tpm-agent) are out of
  scope; their socket paths can be templated like the 1Password path.

## How-to

See [how-to/dotfiles/manage-ssh-config.md](../how-to/dotfiles/manage-ssh-config.md)
and [how-to/sync/ssh-config.md](../how-to/sync/ssh-config.md) for the
click-by-click flows.
