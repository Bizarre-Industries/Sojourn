# Sojourn — security policy

Disclosure policy for Sojourn vulnerabilities. Substantive threat model is
in [docs/explain/threat-model.md](docs/explain/threat-model.md).

## Reporting a vulnerability

Do **not** open a public GitHub issue for security-sensitive bugs.

Two private channels:

1. **GitHub private security advisory** — preferred. Use the *Report a
   vulnerability* button on the repo's *Security* tab.
2. **Email** — `skalghazali@gmail.com` (the maintainer in
   [MAINTAINERS.md](MAINTAINERS.md)).

Include: macOS version, Sojourn version, reproduction steps, observed
impact, and any relevant log excerpts from *Settings → Logs → Export*.

## Response timeline

| Phase | Target |
|---|---|
| Acknowledgement | within **72 hours** |
| Triage + severity rating | within **7 days** |
| Fix in `main` | within **30 days** for High/Critical, best-effort otherwise |
| Public disclosure | coordinated with reporter, default **90 days** after a fixed release |

## Scope

In scope:

- The Sojourn macOS app and its bundled binaries (`gitleaks`, `age`).
- Sojourn's interaction with `mpm`, `chezmoi`, `git`, `defaults`, and any
  package manager Sojourn drives.
- The data-repo schema (`packages.toml`, `machines.toml`,
  `.chezmoiexternal.toml` produced by Sojourn).
- The pre-commit secret-scan flow.

Out of scope:

- Vulnerabilities in upstream package managers (report to Homebrew, npm,
  PyPI, etc. directly).
- Vulnerabilities in `mpm`, `chezmoi`, `gitleaks`, or `age` (report
  upstream; we will track and update bundled versions).
- Issues that require a kernel-level attacker, physical device access,
  or compromise of the user's iCloud/Apple ID.

## Safe-harbour

Good-faith research that follows this policy will not be pursued under
the Computer Fraud and Abuse Act, the DMCA, or equivalent laws. We will
publicly credit researchers in the release notes for the fix unless they
request anonymity.
