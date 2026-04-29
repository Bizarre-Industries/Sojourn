# gitleaks (bundled)

gitleaks v8.30.1 (March 2026), MIT, ~8 MB static Go binary.
[https://github.com/gitleaks/gitleaks](https://github.com/gitleaks/gitleaks).

Ships in `Contents/Resources/bin/gitleaks`, re-signed with Sojourn's Team ID
under `--options=runtime`, stapled as part of the outer notarization. See
[decisions/0006-gitleaks-bundled.md](../../decisions/0006-gitleaks-bundled.md)
and [decisions/0009-bundle-binary-policy.md](../../decisions/0009-bundle-binary-policy.md).

## Rejected alternatives

- **trufflehog**: AGPL-3.0. Flag for any bundling — the network-disclosure
  obligation is narrow for a local desktop but adds legal surface area. Also
  slower, more false positives without verification (which would require
  network egress — privacy regression).
- **detect-secrets**: Python. Requires interpreter. Large (~30–60 MB via
  PyInstaller). Yelp maintenance is effectively cold (v1.5.0, no new tag
  since 2023/24, dependabot-only commits).

## Invocation

```
gitleaks dir --staged --no-git --report-format json
```

Run on pending diffs before each auto-commit. Rules in a bundled
`.gitleaks.toml` with conservative defaults; user can add allowlists per
repo.

## Relationship to chezmoi's `betterleaks`

chezmoi's built-in age encryption covers secret *storage*, not secret
*detection*. gitleaks covers detection. These are complementary, not
overlapping. See [reference/secret-scanning.md](../secret-scanning.md) for
the full pre-commit flow.
