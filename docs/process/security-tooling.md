# Security tooling

Dependency hygiene, supply-chain scanning, and code-level static
analysis for the Sojourn repo. The full stack:

| Tool                        | Layer                             | Cadence                      | Output                |
| --------------------------- | --------------------------------- | ---------------------------- | --------------------- |
| Dependabot version updates  | dependency freshness              | weekly per ecosystem         | grouped PRs           |
| Dependabot security updates | CVE response                      | on-disclosure                | per-CVE PRs           |
| OSV-Scanner                 | runtime vuln scan                 | PR + weekly                  | SARIF in Security tab |
| CodeQL                      | SAST (Swift, Python, Actions, JS) | push + PR + weekly           | SARIF in Security tab |
| zizmor                      | workflow lint                     | PR + weekly                  | SARIF in Security tab |
| pinact                      | one-time + monthly SHA-pin sweep  | manual + monthly cron        | PR                    |
| gitleaks                    | secret scan                       | every commit (in `ci.yml`)   | CI gate               |
| actionlint                  | workflow YAML lint                | every commit (in `Makefile`) | CI gate               |

This document explains how the pieces fit together, why each tool is
in the stack, and the one-time bootstrap a maintainer needs to do.

---

## Bootstrap order

Run these once after the changeset lands. Each step takes ≤2 minutes.

### 1. Commit `Package.resolved`

Currently gitignored. **Without this committed, Dependabot's Swift
support cannot detect transitive vulnerabilities** — the only versions
it can see are the direct ones in `Package.swift`.

```sh
# Remove from .gitignore
sed -i.bak '/^Package\.resolved$/d' .gitignore
rm .gitignore.bak

# Generate it
swift package resolve
git add Package.resolved .gitignore
git commit -s -m "build(swift): commit Package.resolved for Dependabot tracking"
```

Library-vs-app debate: yes, libraries traditionally ignore
`Package.resolved` to let consumers pin. Sojourn ships as a notarized
.app — the dependency graph is fixed at build time and reproducibility
matters more than consumer flexibility. Commit it.

### 2. Enable repo settings

In repo Settings → Code security:

- ✓ Dependency graph
- ✓ Dependabot alerts
- ✓ Dependabot security updates
- ✓ Dependabot version updates (driven by `.github/dependabot.yml`)
- ✓ Grouped security updates
- ✓ Secret scanning (already on for public repos)
- ✓ Push protection (blocks pushing recognised secret patterns)
- ✓ Code scanning → enable for advanced setup (uses our `codeql.yml`)

### 3. Run `pin-actions.yml` once

GitHub UI → Actions → Pin actions → Run workflow.

The workflow runs `pinact`, opens a PR titled
`chore(security): pin actions to commit SHAs` that converts every
`uses: foo/bar@v5` to `uses: foo/bar@<40-char-sha> # v5.0.0` across
all workflow files. Review and merge.

After merge, the `# PIN-SHA-AFTER` comments scattered through the
workflow files will have been replaced with real SHAs. Dependabot's
`gh-actions-all` group then maintains those SHAs weekly.

### 4. First Dependabot run

GitHub UI → Insights → Dependency graph → Dependabot. Click
"Last checked" on each ecosystem to force an immediate scan. The first
run typically opens 1 PR per ecosystem (collated by group) plus any
outstanding security PRs.

---

## How the pieces interact

```
                        ┌─────────────────────┐
                        │   GitHub Advisory   │
                        │   Database (GHSA)   │
                        └──────────┬──────────┘
                                   │
                ┌──────────────────┼──────────────────┐
                │                  │                  │
                ▼                  ▼                  ▼
      ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
      │   Dependabot    │ │    OSV.dev      │ │     Sojourn     │
      │     alerts      │ │   (aggregates   │ │   cooldown      │
      │                 │ │   GHSA + more)  │ │   policy        │
      └────────┬────────┘ └────────┬────────┘ └─────────────────┘
               │                   │           (consumes OSV at
               │                   │            runtime per
               ▼                   ▼            cooldown-policy.md)
      ┌─────────────────┐ ┌─────────────────┐
      │   Dependabot    │ │   OSV-Scanner   │
      │   security PRs  │ │   (CI scan;     │
      │                 │ │   Security tab) │
      └─────────────────┘ └─────────────────┘
```

Sojourn's runtime (cooldown-policy.md, Phase 4 / 14 of
implementation-plan.md) consumes the **same OSV.dev source** that
OSV-Scanner uses to gate the Sojourn binary's CI. The Sojourn product
and the Sojourn repo agree on what counts as a vulnerability.

---

## Dependabot — design decisions

### Why per-ecosystem grouping (not "everything in one PR")

The instinctive ask is "consolidate all Dependabot churn into one PR."
The Dependabot feature that exists is `groups` — but it groups
**within an ecosystem**, not across ecosystems. There's no
"all-ecosystems-one-PR" mode, and that's the right design:

- Mixing a Swift bump with a Python bump means one bad update blocks
  merging the others. Rollback unit becomes the whole PR.
- CI matrix output explodes — every job runs on every change. A Swift
  bump shouldn't re-run the Python ci-local checks.
- Review compounds — eyes glaze at line 200 of cross-ecosystem churn.

What we get instead:

| Cadence                                                                             | Volume    |
| ----------------------------------------------------------------------------------- | --------- |
| One PR per ecosystem per week (max 4: GH Actions, Swift, Python, Docker once added) | Bounded   |
| Plus per-CVE security PRs (any time, any ecosystem)                                 | As needed |

This is the practical "consolidate into as few PRs as possible without
losing atomicity" answer.

### Why version updates and security updates are separate groups

Both ecosystems have a `<eco>-all` group for `version-updates` and a
separate `<eco>-security` group for `security-updates`. Two reasons:

1. **Latency**: a CVE-fix PR shouldn't wait for the next Monday cron
   to ship. Security PRs open immediately on disclosure.
2. **Mergeability**: a security PR has clear "merge this now" framing.
   A grouped version-update PR has "review the diff before merging"
   framing. Mixing them makes the security PR less obviously urgent.

`grouped security updates` (the repo-setting we enable) lets multiple
CVE PRs that happen to land on the same day batch into the same group
PR if we want. Default behaviour stays "one PR per CVE."

### `versioning-strategy: increase` for Swift

Default is `auto`, which respects existing `.upToNextMinor(from:)`
constraints by **not opening PRs for minor bumps** (the constraint
already covers them at resolution time). That defeats the purpose —
we want explicit per-bump PRs so each version landing is reviewed.

`increase` opens a PR even for minor bumps, modifying the constraint
in `Package.swift` to the new floor. Combined with committing
`Package.resolved`, this gives explicit version control.

### `Package.resolved` at the repo root

Dependabot for Swift looks for `Package.resolved` at the repo root
(directory `/`). If it's nested (e.g. `Sojourn.xcworkspace/xcshareddata/swiftpm/Package.resolved`),
the directory in `dependabot.yml` needs to point there. Sojourn's
SPM lockfile is at the root.

### What Dependabot CANNOT do

- **Auto-convert tag pins to SHA pins.** Open feature request from
  2023; no action. We use `pinact` to fill the gap.
- **Detect unpinned actions.** Not in scope. zizmor catches these.
- **Unify "all ecosystems in one PR"** (see above; deliberate).

---

## SHA pinning

### Why

Tag references (e.g. `actions/checkout@v5`) are mutable. Anyone with
write access to `actions/checkout` can re-point `v5` to any commit
they want, and your workflow silently runs the new code on next run.

The 2025 [tj-actions/changed-files compromise](https://stepsecurity.io/blog/changed-files-action-compromise)
is the case study: maintainer keys were stolen, `v45` was rewritten to
exfiltrate secrets, and every workflow using `@v45` ran the malicious
version on next trigger. Repos that pinned to a SHA were unaffected.

GitHub now exposes an org-level policy (Feb 2026) requiring SHA pins
for actions. Sojourn's repo gets ahead of this voluntarily.

### How

Three layers of enforcement:

1. **`pin-actions.yml`** — manual + monthly cron. Runs `pinact`,
   opens a PR with everything pinned. One-time bootstrap, then
   monthly catch-up for anything that slipped in.
2. **`zizmor.yml`** — runs on every PR touching `.github/`. Fails
   the PR if any unpinned action is added. Belt-and-braces against
   contributors not running `make pin-actions` locally.
3. **Dependabot** — once SHAs exist, opens weekly PRs to bump them,
   reading the `# vX.Y.Z` trailing comment to know what version each
   SHA corresponds to.

### What pinact writes

```yaml
# Before:
- uses: actions/checkout@v5

# After pinact run:
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v5.0.0
```

The `# v5.0.0` comment is what Dependabot reads to know "this SHA
corresponds to v5.0.0; check upstream for newer."

---

## CodeQL — design decisions

### Languages

Default Sojourn-style CodeQL setups run only `swift`. We expand to:

| Language              | Runner        | Build mode             | Why                                                                           |
| --------------------- | ------------- | ---------------------- | ----------------------------------------------------------------------------- |
| swift                 | macos-15      | manual (`swift build`) | App code                                                                      |
| python                | ubuntu-latest | none                   | `.github/scripts/check-expiry.py` and any future helpers                      |
| actions               | ubuntu-latest | none                   | Workflow files themselves; catches injection / persisted-credentials patterns |
| javascript-typescript | ubuntu-latest | none                   | Inline `actions/github-script` blocks (the watchdog in `expiry-check.yml`)    |

`actions` as a CodeQL language was added in 2024 and is now the
canonical way to scan workflows for security issues — superset of what
the older "actions" linters caught.

### Pack stack

Three layers per language:

1. **Default suite** — built into the CodeQL bundle. ~166 CWE.
2. **`codeql/<lang>-queries:codeql-suites/<lang>-security-and-quality.qls`**
   — extends to ~201 CWE. This is what
   `.github/codeql/codeql-config.yml` adds via `packs:`.
3. **`githubsecuritylab/codeql-<lang>-queries`** — community pack from
   GitHub Security Lab. Higher-precision experimental queries; some
   land in the official packs eventually.

The action's `queries: security-extended` input layers a fourth source
(extended security queries from the official pack) on top of the
config-file pack stack. Belt + braces.

### Why `security-and-quality` not just `security-extended`

`security-and-quality` is `security-extended` + maintainability /
quality alerts. For an early-stage codebase the quality alerts are
valuable; for a mature codebase they become noise. Sojourn is
early-stage; the broader pack is right now. Switch to
`security-extended` if false-positive rate from the quality pack
becomes a problem.

### Why config-file (not just `queries:` in workflow)

GitHub docs: "For workflows that generate CodeQL databases for
multiple languages, you must instead specify the CodeQL query packs
in a configuration file." Multi-language scans require the
`config-file` approach.

### Path filters

`paths-ignore` excludes:

- `Sojourn/Resources/bin/**` — bundled binaries (gitleaks, age, cosign;
  not source we maintain)
- `.build/**`, `build/**`, `DerivedData/**` — SPM/xcodebuild artefacts
- `**/*.xcodeproj/**` — generated by xcodegen
- `vendor/**`, `third_party/**`, `node_modules/**` — third-party deps

---

## OSV-Scanner — supply-chain scanning at CI time

### Coverage

Reads lockfiles in the repo and queries OSV.dev for advisories:

| Lockfile                           | Ecosystem     |
| ---------------------------------- | ------------- |
| `Package.resolved`                 | Swift         |
| `.github/scripts/requirements.txt` | PyPI (Python) |

OSV.dev aggregates GHSA, RustSec, PyPA, npm advisories, etc., so
coverage is broader than GHSA alone.

### Why both OSV-Scanner and Dependabot security updates

- Dependabot fires when GHSA publishes an advisory and opens a fix PR.
- OSV-Scanner fires on every PR/push and gates merges, regardless of
  whether the advisory has reached GHSA.

A PR that introduces a vulnerable dep version gets blocked at the PR
gate (OSV-Scanner) before it can land; once landed, any subsequently
disclosed CVE shows up as a Dependabot alert + auto-PR. Two layers,
different timing, complementary.

### Why this synergises with Sojourn's product

`docs/reference/cooldown-policy.md` cites OSV.dev as the source of
truth for advisory-aware cooldown bypass. The Sojourn binary at
runtime queries OSV.dev (every 6 hours per
[process/open-questions.md](open-questions.md) §7) to decide whether
to skip cooldown for a known-vulnerable installed version.

Using OSV-Scanner here means the Sojourn repo's own dependency
hygiene is gated by the same advisory source the product relies on.
Dogfooding the threat model.

---

## zizmor — workflow security linter

### What it catches that CodeQL Actions doesn't

zizmor is faster and runs on every PR touching workflow files. It
catches:

- Unpinned action references (the load-bearing thing for SHA pinning).
- `pull_request_target` patterns that leak secrets.
- Persisted credentials misuse.
- Cache-poisoning patterns.
- Excessive permissions.
- Untrusted-input → shell-injection patterns (overlap with CodeQL but
  zizmor is precision-tuned for this case).

Run both. Not redundant.

---

## Maintenance burden

Weekly: review and merge Dependabot's grouped PRs (4 max).
Monthly: review the pin-actions PR if any unpinned action slipped in.
On CVE: review and merge Dependabot's security PR (urgent path).
Otherwise: nothing.

If weekly PRs feel like too much, drop the cadence in
`.github/dependabot.yml` from `weekly` to `monthly`. Don't drop below
that — security responsiveness suffers.

---

## See also

- [maintainer-setup.md](maintainer-setup.md) — initial cert/secret/CI setup. Phase 13 below cross-references this.
- [reference/cooldown-policy.md](../reference/cooldown-policy.md) — OSV.dev usage at Sojourn runtime.
- [decisions/0006-gitleaks-bundled.md](../decisions/0006-gitleaks-bundled.md) — gitleaks shipping rationale; this doc treats secret-scanning as already-solved.
- [process/open-questions.md](open-questions.md) §7 — OSV refresh cadence decision.
