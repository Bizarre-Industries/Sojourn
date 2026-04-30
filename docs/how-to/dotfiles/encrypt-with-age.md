# Encrypt a dotfile with age

## Goal

Encrypt a dotfile in the data repo using the bundled `age` so it lives
ciphertext at rest in git but renders plaintext on apply.

## Prereqs

- Sojourn first run completed (Sojourn generates an `age` identity
  during bootstrap).
- The age recipient public key from the *Settings → Secrets → age*
  pane.
- A dotfile with sensitive content you want to commit but not in
  plaintext.

## Steps

1. **Open the file in the Dotfiles pane**.
2. Click *Encrypt with age*. Sojourn:
   - Renames the source from `dot_aws_credentials` to
     `encrypted_dot_aws_credentials.age`.
   - Encrypts to all configured age recipients (your other Macs +
     any team-key recipients you've added).
3. **Preview** the rendered output via *Preview render* — chezmoi
   decrypts on the fly.
4. **Apply** to write the plaintext to `~/.aws/credentials`.

## Verification

- The source file in the data repo starts with the age header
  (`age-encryption.org/v1`).
- gitleaks finds no high-confidence leaks for the file (encrypted
  bytes don't match secret patterns).
- `chezmoi execute-template --file <source>` renders the original
  plaintext.

## Adding a new Mac as a recipient

When a second Mac onboards, its bootstrap step generates its own age
key. Add the new Mac's public key to your age recipient list:

1. On the new Mac: copy the public key from *Settings → Secrets →
   age*.
2. On any existing Mac: paste it into *Settings → Secrets → age →
   Recipients → Add*.
3. Sojourn re-encrypts every `encrypted_*.age` file in the data repo
   to the expanded recipient set on next push.

## Troubleshooting

- **"Cannot decrypt on Mac B"** — Mac B isn't in the recipient list.
  Add and re-push from Mac A.
- **"`age: error: no identity matched"** — your `~/.config/sojourn/age/identity.txt`
  is missing. Restore from backup or re-run bootstrap.
- **"Re-encrypt taking forever"** — re-encrypts run on every key
  add. Bulk-add new recipients before re-pushing.

## See also

- [how-to/sync/rotate-age-keys.md](../sync/rotate-age-keys.md).
- [reference/secret-brokers.md](../../reference/secret-brokers.md) —
  age as the always-available fallback broker.
- [decisions/0011-secret-broker-abstraction.md](../../decisions/0011-secret-broker-abstraction.md).
