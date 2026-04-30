# Handle a secret-scan finding

## Goal

Triage a finding the pre-commit gitleaks scan surfaced and decide
whether to fix the data, suppress the rule, or commit anyway.

## Prereqs

- An active push attempt that Sojourn has just paused on a finding.

## Steps

1. **Read the finding banner.**

   Sojourn's modal shows:

   - Finding count by severity.
   - The exact match (with a short context window).
   - The matching rule ID and description.
   - File path and line number.

   For **high-confidence provider keys** (AWS, GitHub PAT, OpenAI,
   Stripe live, Anthropic, Slack token), the *Commit anyway* button is
   disabled for 5 seconds and the modal shows a red banner. Read the
   match before clicking.

2. **Decide what's actually there.**

   Three cases:

   - **It is a real secret you accidentally committed.** Stop. Fix
     the file: replace the value with a 1Password / Bitwarden /
     `age` reference, or a placeholder like `REDACTED`. **Then
     rotate the credential** — it has been on disk in plaintext, so
     consider it leaked even if you catch it before push.
   - **It is a false positive** (test fixture, example, public-by-design
     value). Add an allowlist entry to `.gitleaks.toml` per
     [customize-gitleaks-rules.md](customize-gitleaks-rules.md). Then
     re-run the scan.
   - **It is a real value you intend to commit** (e.g. a public AWS
     bucket name that gitleaks regex-matched). Add a rule-level
     allowlist for that file or value.

3. **Fix the file** if it's case 1 or 3.

   - For 1Password: see
     [how-to/dotfiles/encrypt-with-1password.md](../dotfiles/encrypt-with-1password.md).
   - For age:
     [how-to/dotfiles/encrypt-with-age.md](../dotfiles/encrypt-with-age.md).
   - For redaction: edit the file, replace the value with a
     placeholder, save, re-trigger the push.

4. **Update the allowlist** if it's case 2.

   Edit `.gitleaks.toml` at the data-repo root with a `[[allowlist]]`
   block scoped narrowly (specific path + specific rule ID).

5. **Rotate the credential** if you found a real leak.

   Even before push, the secret was on disk in plaintext during your
   editing session. Treat as leaked:

   - For AWS keys: revoke at the IAM console, generate new ones.
   - For GitHub PATs: revoke at GitHub Settings → Developer settings.
   - For Stripe live keys: rotate at Stripe Dashboard → Developers.
   - Document the rotation in your team's incident log if applicable.

6. **Re-trigger the push.**

   Sojourn re-scans automatically. If the finding is gone (fixed or
   allowlisted), proceed with the push.

## Verification

- The pre-commit modal closes cleanly with "0 findings".
- The push lands.
- gitleaks dir on the data repo (post-push) shows no high-confidence
  findings.

## Troubleshooting

- **"Same finding fires after fix"** — the file is staged. Re-stage
  after the edit (`git add <file>`).
- **"Allowlist doesn't suppress finding"** — gitleaks allowlist paths
  are regex; verify the regex actually matches. Test with
  `gitleaks detect`.
- **"Bypass button stays disabled"** — the 5-second lockout is
  intentional for high-confidence findings. Wait. If the lockout
  exceeds 5 seconds, you've found a bug; report via
  [SECURITY.md](../../../SECURITY.md).

## Do not

- **Do not** commit a real secret and rotate later. Sojourn's flow is
  designed to catch this; the rotation-then-commit is the correct
  order.
- **Do not** disable secret scanning globally to bypass a single
  finding. Every other commit then ships unscanned.

## See also

- [decisions/0006-gitleaks-bundled.md](../../decisions/0006-gitleaks-bundled.md)
  — why bundled gitleaks + 5s lockout.
- [explain/threat-model.md](../../explain/threat-model.md) — full
  secret-handling posture.
- [how-to/secrets/customize-gitleaks-rules.md](customize-gitleaks-rules.md).
