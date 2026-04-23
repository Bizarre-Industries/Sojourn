# Sojourn — Maintainers

The following person is responsible for Sojourn releases, security response,
and dependency review.

| Role | Name | Contact |
|---|---|---|
| Maintainer | Suhail Albooshi | skalghazali@gmail.com |

## Security response

Please do **not** open a public GitHub issue for security-sensitive bugs.
Use GitHub's private security advisory form on the repo, or email the
maintainer at the address above.

Expected response time: 72 hours. Disclosure timeline: coordinated with
reporter, default 90 days after a fixed release. See
[docs/SECURITY.md](docs/SECURITY.md) for the full policy.

## Release authority

Version tags (`vX.Y.Z`) trigger `.github/workflows/notarize.yml`. Only the
maintainer holds:

- Apple Developer ID Application certificate + private key.
- `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `DEVELOPMENT_TEAM` secrets.
- `HOMEBREW_TAP_TOKEN` for cask publish.
- GitHub OAuth App `client_id` for Device Flow (see
  `Sojourn/Services/GitHubDeviceAuth.swift` once landed).

## Decision log

Architectural decisions are tracked in PR descriptions and in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Material changes to the
"Do not do" list in [CLAUDE.md](CLAUDE.md) require an explicit PR.
