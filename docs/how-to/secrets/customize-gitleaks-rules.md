# Customise gitleaks rules

## Goal

Tune the secret-scan rules for your data repo: add per-repo allowlists,
silence specific rule IDs, or add custom regex rules for org-internal
secret patterns.

## Prereqs

- A working Sojourn install with the bundled `gitleaks` v8.30+
  (`Contents/Resources/bin/gitleaks`).
- A data repo where Sojourn already commits.
- Knowledge of gitleaks rule syntax —
  [gitleaks.toml format](https://github.com/gitleaks/gitleaks/blob/master/config/gitleaks.toml).

## Steps

1. **Locate the bundled default rules**:

   The bundled rules live at `Contents/Resources/data/gitleaks.toml`
   inside Sojourn.app. Sojourn applies them on every pre-commit scan.
   Don't edit the bundle directly — your changes get blown away on
   reinstall.

2. **Create a per-repo override** at `<data-repo>/.gitleaks.toml`:

   ```toml
   [extend]
   useDefault = true
   path = ".gitleaks.toml"

   [[rules]]
   id = "internal-api-key"
   description = "Acme Co. internal API keys"
   regex = '''ACME_[A-Z0-9]{32}'''
   tags = ["key", "Acme"]

   [[allowlist]]
   description = "Test fixtures with example keys"
   paths = [
     '''^test/fixtures/.*''',
     '''^examples/.*\.example$''',
   ]
   ```

   Sojourn merges your `.gitleaks.toml` with the bundled defaults.
   Your rules add to the bundle; your allowlists subtract from it.

3. **Test locally** before committing:

   ```sh
   /Applications/Sojourn.app/Contents/Resources/bin/gitleaks dir \
     --config=.gitleaks.toml \
     --report-format=json \
     --report-path=-
   ```

   Expected: no findings on intentional fixtures, real findings on
   committed-by-mistake test secrets.

4. **Commit the rules file**:

   ```sh
   git add .gitleaks.toml
   git commit -s -m "scan: add internal-api-key rule + allowlist test fixtures"
   ```

   Sojourn auto-detects the rules file on next push and uses it.

5. **Confirm Sojourn picked them up**:

   - *Settings → Secret scanning* shows
     "Per-repo rules: `.gitleaks.toml` (12 rules + 3 allowlists)".
   - Trigger a test commit; Sojourn's pre-commit modal lists the
     applied rules.

## Verification

- The Settings → Secret scanning row shows the per-repo file path
  and rule count.
- A staged file with an `ACME_*` token triggers the
  *internal-api-key* rule.
- A staged file under `test/fixtures/` does not trigger.

## Troubleshooting

- **"Per-repo rules: none"** — Sojourn looks for `.gitleaks.toml` at
  the data-repo root. Verify the file is named exactly that and is
  committed.
- **"Rule not firing"** — gitleaks regex follows Go regexp syntax.
  Test the regex with `gitleaks detect --rules-path /tmp/test.toml`
  and a known-bad fixture.
- **"Too many false positives"** — start with `useDefault = true`
  then add `[[allowlist]]` blocks for the noisy paths instead of
  disabling rules outright.

## See also

- [reference/secret-brokers.md](../../reference/secret-brokers.md).
- [decisions/0006-gitleaks-bundled.md](../../decisions/0006-gitleaks-bundled.md)
  — why gitleaks (not trufflehog).
- [how-to/secrets/handle-finding.md](handle-finding.md) — what to do
  when a finding fires during a real commit.
