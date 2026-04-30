# Add Bitwarden as a secret broker

## Goal

Add Bitwarden alongside (or instead of) 1Password as Sojourn's secret
broker.

## Prereqs

- Bitwarden 2024.5.0+ desktop app installed.
- The `bw` CLI on `PATH`. Install via `brew install bitwarden-cli`.
- A Bitwarden account; vault unlocked.

## Steps

1. **Verify the CLI**:

   ```sh
   which bw
   bw --version
   bw status
   ```

   `bw status` should report `unlocked` after `bw unlock` runs once.

2. **Persist the session token** for the current Mac so Sojourn can
   call `bw` without prompting:

   ```sh
   export BW_SESSION="$(bw unlock --raw)"
   echo "export BW_SESSION='$BW_SESSION'" >> ~/.zshrc.local
   ```

   `~/.zshrc.local` should already be ignored by chezmoi (the local
   override convention).

3. **Open Sojourn → Settings → Secrets**.

   Sojourn detects `bw` and adds *Bitwarden* to the dropdown.

4. **Set priority**:

   - To use Bitwarden as primary: *Set as primary*.
   - To use Bitwarden as a secondary fallback (e.g. for items not in
     1Password): leave 1Password primary; Sojourn tries 1Password first
     and falls back to Bitwarden when an item isn't found.

5. **Convert a dotfile**:

   In the Dotfiles pane, *Convert to Bitwarden reference* writes a
   chezmoi template using `{{ bitwarden "item" "<id-or-name>" "field" }}`
   syntax.

6. **Verify**:

   ```sh
   chezmoi execute-template --file <source-path>
   ```

## Verification

- Settings → Secrets shows *Bitwarden* with a green indicator.
- `bw status` reports `unlocked`.
- Templated dotfiles render the correct secret values.
- gitleaks finds no leaks.

## Troubleshooting

- **"`bw` returns null"** — the item ID has changed. `bw list items
  --search <name>` finds the current ID.
- **`BW_SESSION` expired** — Bitwarden sessions time out by default
  (15 min). Re-run `bw unlock --raw` and update the session env
  variable. For long sessions, set `BW_TIMEOUT` higher in Bitwarden's
  CLI config.
- **"Two-factor prompt loops"** — `bw login --apikey` skips 2FA after
  initial setup; use that for a CI-style flow.

## See also

- [reference/secret-brokers.md](../../reference/secret-brokers.md) —
  fallback-ladder semantics when multiple brokers are configured.
- [how-to/secrets/set-up-1password.md](set-up-1password.md) — primary
  broker.
- [decisions/0011-secret-broker-abstraction.md](../../decisions/0011-secret-broker-abstraction.md).
