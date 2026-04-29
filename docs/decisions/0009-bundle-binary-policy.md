# 0009 — Bundle gitleaks + age inside the app; do not bundle mpm or chezmoi

- **Status**: Accepted
- **Date**: 2026-04-24
- **Deciders**: Sojourn maintainer

## Context

Sojourn invokes external CLIs as separate processes per
[0001-ipc-not-linking.md](0001-ipc-not-linking.md). The question: which of
these CLIs ship inside `Contents/Resources/bin/`, and which live in the
user's `PATH` and are installed via the bootstrap flow?

Trade-offs to weigh per binary:

- **Update cadence** — fast-moving tools that bundle become stale; user
  copy is fresher.
- **Notarization burden** — each bundled binary must be re-signed and
  passes through outer notarization.
- **Discoverability** — bundled binary is always present; PATH binary may
  be missing on first run.

## Decision

| Binary | Bundled? | Rationale |
|---|---|---|
| `gitleaks` | Yes (`Contents/Resources/bin/gitleaks`) | Always-needed for pre-commit scanning. Stable feature surface. ~8 MB. Updates ~quarterly. |
| `age` | Yes (`Contents/Resources/bin/age`) | Required by chezmoi for passphrase/SSH age modes. Tiny (~3 MB). MIT. |
| `mpm` | No — installed via `brew install meta-package-manager` or fallback Nuitka binary | Updates often (~bi-weekly); shipping a frozen Python interpreter complicates notarization. |
| `chezmoi` | No — installed via `brew install chezmoi` or direct binary download | Active upstream cadence; signed + notarized upstream. |
| `brew` | No — installed via signed `.pkg` ([0008](0008-no-curl-bash-for-brew.md)) | Refuses non-default prefixes; self-updates. |
| `git` | No — system `/usr/bin/git`, triggers Xcode CLT install when missing | Always available on Mac dev systems. |
| `defaults` / `plutil` | No — Apple system tools | Always available. |

Both bundled binaries are re-signed with Sojourn's Developer ID under
`--options=runtime` and stapled as part of outer notarization.

## Consequences

### Positive

- Always-present security tooling (gitleaks for scans, age for
  encryption) means push/pull never fails because a tool is missing.
- mpm + chezmoi stay current with upstream without Sojourn rebuild
  requirements.
- DMG size stays modest (~12 MB of bundled binaries).

### Negative

- Re-signing burden each release for the two bundled binaries.
- Bootstrap complexity for the unbundled tools (state machine in
  `BootstrapService`).

### Neutral

- License-wise: gitleaks (MIT) and age (MIT) are bundleable without
  copyleft propagation. Bundling GPL-2.0-only `mpm` would be more
  delicate even if technically possible.

## Alternatives considered

- **Bundle everything** — rejected. mpm + chezmoi update too often;
  bundling forces Sojourn rebuilds for upstream-only changes.
- **Bundle nothing; install all on first run** — rejected. gitleaks +
  age are needed even mid-session; first-run delays compound.
