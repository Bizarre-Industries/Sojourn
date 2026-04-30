# Rotate age keys

## Goal

Replace the `age` identity Sojourn uses for encrypted dotfiles —
typically because a private key was exposed, a Mac was lost, or you
want to remove a Mac that is no longer trusted from the recipient
list.

## Prereqs

- An age identity already in use (`encrypted_*.age` files exist in the
  data repo).
- All Macs that should retain access are online (or at least available
  to pull when the rotation finishes).

## Steps

1. **Open Sojourn → Settings → Secrets → age**.

2. **Decide the rotation type**:

   - **Replace this Mac's identity** — generate a new keypair on this
     Mac; the old one becomes invalid here.
   - **Remove a peer Mac** — keep this Mac's identity; remove a peer's
     public key from the recipient list (e.g. when retiring a Mac).
   - **Full re-key** — generate new identities on every Mac and
     re-encrypt every file.

3. **Use the corresponding flow**:

   ### Replace this Mac's identity

   1. Click *Generate new identity*. Sojourn:
      - Backs up the old identity to `~/Library/Application Support/Sojourn/backups/<ts>-age/identity.txt.old`.
      - Writes a new `~/.config/sojourn/age/identity.txt`.
      - Adds the new public key to the recipient list and removes
        the old.
   2. **Re-encrypt** with *Re-encrypt all files*. Sojourn iterates
      every `encrypted_*.age` and re-encrypts to the updated
      recipient list.
   3. **Push**.

   ### Remove a peer Mac

   1. In the recipient list, click *Remove* on the peer's public
      key.
   2. *Re-encrypt all files*. Files now decrypt only on remaining
      Macs.
   3. **Push**.
   4. On the removed Mac (if you have access), revoke its access by
      deleting the data-repo clone — Sojourn won't decrypt without a
      pull anyway.

   ### Full re-key

   1. On every Mac in turn: *Generate new identity*.
   2. After all Macs have new keys, *Re-encrypt all files* on the
      Mac that holds the writer lock.
   3. **Push**. Other Macs pull and decrypt with their new keys.

4. **Verify decryption** on each Mac:

   ```sh
   chezmoi execute-template --file <encrypted-source>
   ```

   Should render plaintext on every Mac that should still have
   access.

## Verification

- Old identity is in `backups/<ts>-age/`, not in active config.
- New identity decrypts every `encrypted_*.age` file.
- Peer Mac that was removed cannot decrypt (verify before retiring).
- gitleaks finds no leaks (re-encrypted files are still encrypted).

## What this does not protect against

- A copy of the old private key already in someone's hands. Rotation
  doesn't undo prior access; once a private key is exposed, every
  past version of every encrypted file is exposed.
- For high-stakes secrets, **rotate the underlying credential**
  (the AWS key, GitHub PAT, etc.) as well as the age key.

## Troubleshooting

- **"Re-encrypt fails with 'no recipients'"** — the recipient list
  is empty. Add at least this Mac's new public key first.
- **"Peer Mac can't decrypt after re-key"** — peer's identity isn't
  in the recipient list. Check Settings → Secrets → age → Recipients
  on the writer Mac.
- **"Old identity still works"** — Sojourn doesn't delete the
  backup. The old key still decrypts files encrypted with it
  (i.e. anything pushed before re-encrypt). Wipe the backup if
  truly needed.

## See also

- [how-to/dotfiles/encrypt-with-age.md](../dotfiles/encrypt-with-age.md).
- [reference/secret-brokers.md](../../reference/secret-brokers.md) —
  age as the always-available fallback.
- [explain/threat-model.md](../../explain/threat-model.md).
