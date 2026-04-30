# Set up 1Password as Sojourn's secret broker

## Goal

Configure 1Password as the primary secret broker for Sojourn, so any
dotfile that contains a credential references the 1Password item
instead of the plaintext value.

## Prereqs

- 1Password 8.10.30+ for Mac (the version with `op` CLI bundled).
- Signed in to 1Password, biometric / Apple Watch unlock enabled.
- 1Password CLI integration enabled: *1Password → Settings → Developer
  → Integrate with 1Password CLI*.
- A vault Sojourn can read (typically *Personal* or a dedicated *Dev*
  vault).

## Steps

1. **Verify the CLI is on `PATH`**:

   ```sh
   which op
   op --version
   ```

   Expected: a path under `/usr/local/bin/op` or `/Applications/1Password.app/Contents/MacOS/op`,
   version 2.30+.

2. **Authorise the desktop integration** for the current shell:

   ```sh
   op signin
   ```

   You should be prompted via 1Password's biometric unlock, not for a
   master password.

3. **Open Sojourn → Settings → Secrets**.

   Sojourn auto-detects `op` and shows it as available. The "Default
   secret broker" dropdown should now offer *1Password* alongside
   *age*, *Keychain*, and *plaintext (refuse)*.

4. **Choose 1Password as primary**.

   Click *Set as primary*. Sojourn writes the priority into
   `<data-repo>/.chezmoi/chezmoi.toml`:

   ```toml
   [data]
     sojourn_secret_broker = "1password"
   ```

5. **Run a test reference**.

   Pick a dotfile with a credential (e.g. `.aws/credentials`). Click
   *Convert to 1Password reference* in the Dotfiles pane. Sojourn:

   - Asks which 1Password vault + item to use.
   - Rewrites the dotfile as a chezmoi template using
     `{{ onepasswordRead "op://Personal/aws-prod/secret-access-key" }}`.
   - Shows a preview before saving.

6. **Verify the rendered output**:

   ```sh
   chezmoi execute-template --file <source-path>
   ```

   The rendered content should show the actual secret pulled from
   1Password.

## Verification

- Settings → Secrets shows *1Password* with a green indicator.
- The dotfile in the data repo contains an `op://` reference, not the
  plaintext.
- `chezmoi apply --dry-run` shows the value would be rendered
  correctly.
- Running gitleaks on the data repo (`gitleaks dir`) finds **no
  high-confidence leaks** for the rewritten file.

## Troubleshooting

- **"`op` not detected"** — Sojourn checks the
  `/Applications/1Password.app` path and `$PATH`. If you installed
  1Password via `brew install --cask 1password`, restart Sojourn
  (LaunchServices `PATH` update).
- **"Touch ID prompt loops"** — your shell's `op` session has
  expired. Run `op signin` in Terminal once; Sojourn inherits the
  agent.
- **"`onepasswordRead` returns empty"** — the item or vault name has
  changed. Re-run *Convert to 1Password reference* and pick the new
  path; chezmoi templates fail loudly on missing references.

## See also

- [reference/secret-brokers.md](../../reference/secret-brokers.md) —
  full provider matrix and fallback ladder.
- [decisions/0011-secret-broker-abstraction.md](../../decisions/0011-secret-broker-abstraction.md)
  — secret-broker design.
- [how-to/secrets/add-bitwarden.md](add-bitwarden.md) — alternative
  broker.
- [how-to/dotfiles/encrypt-with-1password.md](../dotfiles/encrypt-with-1password.md)
  — companion task for new dotfiles that contain secrets.
