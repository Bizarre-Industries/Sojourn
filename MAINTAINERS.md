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
[SECURITY.md](SECURITY.md) at the repo root for the disclosure policy +
[docs/explain/threat-model.md](docs/explain/threat-model.md) for the
threat model (lands in Phase 8 of the docs rework).

## Release authority

Version tags (`vX.Y.Z`) trigger `.github/workflows/notarize.yml`. Only the
maintainer holds:

- Apple Developer ID Application certificate + private key.
- `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `DEVELOPMENT_TEAM` secrets.
- `HOMEBREW_TAP_TOKEN` for cask publish.
- GitHub OAuth App `client_id` for Device Flow (see
  `Sojourn/Services/GitHubDeviceAuth.swift` once landed).

## Decision log

Architectural decisions are tracked in
[docs/decisions/](docs/decisions/) (immutable ADR log) and in
[docs/reference/architecture.md](docs/reference/architecture.md).
Material changes to the "Do not do" list in [CLAUDE.md](CLAUDE.md)
require an explicit PR plus a new ADR if architectural.
