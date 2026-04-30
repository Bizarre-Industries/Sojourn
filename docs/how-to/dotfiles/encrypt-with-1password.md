# Reference 1Password from a dotfile

## Goal

Replace a plaintext credential in a dotfile with a `op://` reference
that resolves to the live secret stored in 1Password.

## Prereqs

- 1Password is set up as a Sojourn secret broker — see
  [how-to/secrets/set-up-1password.md](../secrets/set-up-1password.md).
- A dotfile (e.g. `~/.npmrc`, `~/.aws/credentials`) that contains a
  credential.
- A 1Password item that already holds that credential.

## Steps

1. **Open the dotfile** in the Dotfiles pane.
2. Click *Convert to 1Password reference*. Sojourn:
   - Asks which 1Password vault and item.
   - Asks which field of that item (default: the field whose value
     matches the current plaintext).
   - Rewrites the source as a chezmoi template with
     `{{ onepasswordRead "op://<vault>/<item>/<field>" }}`.
3. **Preview render** — Sojourn invokes `op` and shows the rendered
   plaintext.
4. **Apply** — `chezmoi apply` writes the plaintext to the destination.

## Verification

- The source in the data repo contains `op://...`, not the plaintext.
- gitleaks finds no high-confidence leaks for the file.
- `~/.npmrc` (or wherever) contains the actual secret after apply.

## Troubleshooting

- **"`op` returns empty"** — vault name or item changed. Open
  1Password, copy the new `op://` URI, edit the template manually.
- **"Touch ID prompt loops on apply"** — `op` session expired.
  Re-run `op signin` once in Terminal; Sojourn inherits the agent.
- **"Multiple Macs without 1Password"** — for Macs without 1Password
  installed, this template fails. Use age fallback (see
  [encrypt-with-age.md](encrypt-with-age.md)) or install 1Password
  there.

## See also

- [how-to/secrets/set-up-1password.md](../secrets/set-up-1password.md).
- [reference/secret-brokers.md](../../reference/secret-brokers.md) —
  full provider matrix.
- [encrypt-with-age.md](encrypt-with-age.md) — alternative when
  1Password isn't available.
