# Manage your SSH config

## Goal

Sync `~/.ssh/config`, `~/.ssh/known_hosts`, and `~/.ssh/allowed_signers`
across Macs without leaking private keys or per-machine identifiers.

## Prereqs

- Sojourn first run completed.
- A working `~/.ssh/config` you want to track.

## What Sojourn syncs and doesn't

| File | Sync? | Notes |
|---|---|---|
| `~/.ssh/config` | **Yes** | Templated for per-Mac differences. |
| `~/.ssh/known_hosts` | **No** by default | Per-Mac state; opt-in via *Settings → Dotfiles*. |
| `~/.ssh/allowed_signers` | **Yes** | If you commit-sign with SSH. |
| `~/.ssh/id_*` (private keys) | **Never** | Generate per-Mac; reference in `config` only. |
| `~/.ssh/id_*.pub` (public keys) | Optional | Tracked if you opt in; helpful for `authorized_keys` reconciliation. |
| `~/.ssh/authorized_keys` | **No** | Per-Mac; defines who can SSH **in**, not **out**. |

## Steps

1. **Open the Dotfiles pane**. Sojourn shows `~/.ssh/config` with a
   warning if it's not yet tracked.
2. Click *Track this file* on `~/.ssh/config`.
3. **Make it a template** if it has per-Mac sections:

   ```gotmpl
   Host work-jumphost
       User suhail
       {{- if eq .chezmoi.hostname "binghzals-MBP" }}
       IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
       {{- else }}
       IdentityFile ~/.ssh/id_ed25519
       {{- end }}
   ```

4. **Confirm `~/.ssh/id_*` is in `.chezmoiignore`**:

   ```sh
   chezmoi forget ~/.ssh/id_ed25519 2>&1 || true
   echo '.ssh/id_*' >> ~/.local/share/chezmoi/.chezmoiignore
   ```
5. **Push** — config syncs; private keys stay local.

## Per-Mac key generation

For a fresh Mac onboarding:

1. Pull the repo. `~/.ssh/config` lands.
2. Sojourn shows a *Generate SSH key* prompt for each `IdentityFile`
   referenced in `config`.
3. Click *Generate*. Sojourn runs `ssh-keygen -t ed25519 -f
   ~/.ssh/id_ed25519 -N ""` (or with a passphrase prompt).
4. Add the new public key to your Git host (GitHub: *Settings → SSH
   and GPG keys*).

## Verification

- `~/.ssh/config` is in the data repo (templated where needed).
- `~/.ssh/id_*` is **not** in the data repo (`git status` confirms).
- `ssh -T git@github.com` works on every Mac.
- `git commit -s -S` (SSH signing) works if you use it.

## Troubleshooting

- **"`known_hosts` warnings on every fresh Mac"** — that's expected
  by default. To opt in: *Settings → Dotfiles → Track known_hosts*
  and re-pull.
- **"1Password SSH agent socket path differs"** — the path includes
  the user's team ID. Either templated per-Mac or fall back to
  `IdentityAgent ~/.1password/agent.sock` (the symlink 1Password
  creates).
- **"Public key in repo, private key not"** — keys go on the same
  Mac. Sojourn refuses to commit `.ssh/id_*` (no extension); pubkeys
  end in `.pub`. Verify which file you're staging.

## See also

- [reference/ssh-config.md](../../reference/ssh-config.md) — full
  policy.
- [process/audit-2026-04.md §2.5](../../process/audit-2026-04.md#25-ssh-specific-gaps)
  — original gap.
- [explain/threat-model.md](../../explain/threat-model.md) — why
  private keys never leave their Mac.
