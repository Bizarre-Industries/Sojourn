# The tier model

Why Sojourn classifies package ecosystems into tiers A–E, why the
default cooldown is 7 days, and what the model deliberately does not
protect against. The decision is in
[decisions/0003-cooldown-7-days.md](../decisions/0003-cooldown-7-days.md);
the per-ecosystem ladder lives in
[reference/cooldown-policy.md](../reference/cooldown-policy.md). This
page is the rationale.

## Why tiers at all

Different package ecosystems have different supply-chain attack
characteristics. Treating them uniformly produces either a uselessly
permissive default (npm gets the same treatment as Mac App Store) or
a uselessly conservative one (Mac App Store updates wait 7 days
because npm needs to). Tiers separate them.

Each tier captures three signals:

1. **Curation depth** — does a human review every release?
2. **Typical attack window** — how long between malicious publish and
   detection / removal?
3. **Maintainer attack surface** — single-maintainer registries with
   permissive publish rules sit in the highest-risk tier.

## The five tiers

| Tier | Ecosystem | Curation | Cooldown | Behavior |
|---|---|---|---|---|
| A | Mac App Store | Apple review | 0 days | Auto |
| B | brew formulae, cargo | Distro/community curation | 7 days | Auto |
| C | brew casks, pinned pip / uv project deps | Vendor binaries / lockfile-pinned | 7 days | User prompt |
| D | global pip / pipx | Single-maintainer often | 7 days | User prompt |
| E | global npm | Permissive publish + post-install scripts | 14 days | Never silent |

Tier A trusts Apple. Tier E trusts no one and forces per-version
approval. The middle tiers split on whether a human curator stands
between the malicious publish and the user's machine.

## Why 7 days as the default

The 72-hour figure from 2020-era writeups is too aggressive. Modern
incident data points the other way:

- **axios 1.14.1 / 0.30.4** (Mar 31, 2026) — malicious 2–4 hours.
- **Shai-Hulud 1** (Sep 15, 2025) — 187 packages, self-replicating
  worm.
- **Shai-Hulud 2.0** (Nov 24, 2025) — 796 packages, 20M weekly
  downloads.
- **s1ngularity / Nx** (Aug 26–27, 2025) — SSH-key + GitHub-token
  exfiltration, 4–5 hour window.
- **chalk / debug / tinycolor phishing** (Sep 2025) — ~2B weekly
  downloads affected.
- Earlier: **ua-parser-js** (Oct 2021, ~4h), **Solana web3.js** (Dec
  2024, ~5h), **Ledger Connect Kit** (Dec 2023, ~5h).

Every one of these had a published-to-detected window under 8 hours.
A 24-hour cooldown blocks them all. 72 hours adds margin for weekend
publishes (Friday-evening attacker → community detection on Monday
morning). 7 days adds further margin for holiday weekends and is the
**2026 industry consensus** — Datadog, Renovate
(`config:best-practices`), Dependabot, and Mend converge here.

Snyk hardcodes 21. Renovate's npm default is 3 days plus weekend
padding. Sojourn picks 7 because it's the conservative end of the
modern range without crossing into "users perceive Sojourn as falling
behind."

## OSV / GHSA bypass

Cooldown protects against unknown-bad publishes. It must not strand
users on **known-bad** versions. So:

- The daily background activity hits `api.osv.dev` and pulls advisory
  data for currently-installed package versions.
- If an advisory is published for the *currently-installed* version,
  the cooldown is bypassed for the upgrade — Sojourn updates
  immediately.
- The bypass is one-way: Sojourn upgrades on advisory but does not
  downgrade to dodge cooldown.

This is the policy that lets Sojourn promise "you will never sit on a
known-vulnerable package because of a cooldown rule".

## What cooldown does not protect against

- **Multi-year maintainer infiltration.** The xz backdoor
  (CVE-2024-3094) is the flagship case — 2-year ramp from initial
  contribution to malicious release. No cooldown helps. User-facing
  copy must say so to prevent false confidence.
- **Compromised tool versions older than the cooldown.** If a
  pre-cooldown version goes malicious 30 days after publish,
  cooldown's already-passed window doesn't help. OSV bypass catches
  this when an advisory is published.
- **Supply-chain attacks on Sojourn itself.** Out of scope here; see
  [explain/threat-model.md](threat-model.md) for what Sojourn does to
  defend its own bundled binaries.

## Why not configurable per-package

Per-package cooldowns are a power-user feature deferred to a later
release. The v1 model is per-tier with a single global override
("trust this ecosystem more / less"). Per-package adds UX
complexity (a list of pinned cooldowns the user has to maintain)
without much real-world need — the long-tail packages that need
overrides are rare enough that the user can pin a version manually.

If the deferred-work backlog ever ships per-package cooldowns, they
go in `packages.toml` per-machine override syntax (see
[reference/file-formats/packages-toml.md](../reference/file-formats/packages-toml.md)
when it lands).

## See also

- [decisions/0003-cooldown-7-days.md](../decisions/0003-cooldown-7-days.md)
  — the formal decision record.
- [reference/cooldown-policy.md](../reference/cooldown-policy.md) —
  full evidence base + per-tier table + advisory bypass behaviour.
- [explain/threat-model.md](threat-model.md) — supply-chain risk
  posture.
- [process/open-questions.md](../process/open-questions.md) §7 —
  OSV/GHSA fetch frequency + feed source (open).
