# Auto-update safety / cooldown policy

> **Audit driver**: closes [process/audit-2026-04.md §1.3](../process/audit-2026-04.md#1-doc-level-inconsistencies) (casks reconciled to "C, 7d") + tracks §2.1.3 (`mpm sync` daily refresh) + §2.1.4 (`mpm cleanup`) + closes [process/open-questions.md](../process/open-questions.md) §7 (OSV refresh cadence + feed source).

**Default cooldown: 7 days.** The 72-hour figure from 2020-era writeups is
now too aggressive given weekend publish windows. 7 days is the 2026
consensus (Datadog, Renovate's `config:best-practices` for npm defaults to
3 days but adds weekend padding discussion; Dependabot and Mend converge
around 7; Snyk hardcodes 21; uv and Renovate both support configurable
durations). See
[decisions/0003-cooldown-7-days.md](../decisions/0003-cooldown-7-days.md).

## Evidence base — incidents 2024–2026 a 7-day gate blocks outright

- **axios 1.14.1 / 0.30.4** (Mar 31, 2026) — malicious 2–4 hours.
- **Shai-Hulud 1** (Sep 15, 2025, 187 packages incl. @crowdstrike/*) —
  self-replicating worm.
- **Shai-Hulud 2.0** (Nov 24, 2025, 796 packages, 20M weekly downloads).
- **s1ngularity / Nx** (Aug 26–27, 2025) — SSH key + GitHub token
  exfiltration, 4–5 hour window.
- **chalk/debug/tinycolor phishing** (Sep 2025) — ~2B weekly downloads
  affected.
- **ua-parser-js** (Oct 2021, ~4h), **Solana web3.js** (Dec 2024, ~5h),
  **Ledger Connect Kit** (Dec 2023, ~5h).

The **xz backdoor** (CVE-2024-3094) is the flagship case where no cooldown
helps — multi-year maintainer infiltration. User-facing copy should say so
to avoid false confidence.

## Per-ecosystem tiers

| Tier | Ecosystem | Default behavior | Cooldown |
|---|---|---|---|
| A safest | Mac App Store (`mas`) | Auto | 0 |
| B safe | Homebrew formulae | Auto | 7 days |
| B safe | `cargo` | Auto | 7 days |
| C moderate | Homebrew casks | User prompt | 7 days |
| C moderate | Pinned `pip` / `uv` project deps | Auto | 7 days |
| D risky | Global `pip` / `pipx` | User prompt | 7 days |
| E high-risk | Global `npm` | **Never auto-update silently** | 14 days |

Hard rule: **never auto-run an install that would execute `preinstall` /
`postinstall` / build scripts without user confirmation**, even inside
cooldown.

Per-manager tier assignment lives in
[reference/package-managers/index.md](managers/README.md).

## Advisory-aware cooldown

If OSV / GHSA has a published advisory for the **old** version, bypass the
cooldown and update.

### Source

**OSV.dev only.** GHSA records are already aggregated into OSV.dev via
`github.com/github/advisory-database`, which publishes GHSA entries in
OSV format and is one of OSV.dev's primary upstream sources. Querying
GHSA directly adds nothing in coverage; only marginal freshness (sub-hour
import lag), which is in the noise at any sensible refresh cadence. See
[process/open-questions.md](../process/open-questions.md) §7.

### Frequency

**Every 6 hours (4× per day).** Daily refresh has worst-case 24h
staleness — bad for the OSV-bypass promise that says you'll never sit on
a known-vulnerable version because of a cooldown rule
([explain/tier-model.md](../explain/tier-model.md)). The 2024–2026
incident-window data above shows 2–8h disclosure-to-detection windows;
6-hourly cuts worst-case to ~6h while staying inside `api.osv.dev` rate
limits and `NSBackgroundActivityScheduler` budgets (DAS/CTS scheduling
handles thermal/battery state).

Going more aggressive (e.g. hourly) buys diminishing returns past the
4–8h incident window and risks rate-limit pushback + App Nap conflict.

### Mechanism — delta-fetch via `modified_id.csv`

Per-package POST queries against `api.osv.dev` don't scale: a typical
Sojourn install has 200+ brew formulae, 50+ npm globals, 40+ cargo
crates, 1000+ POSTs/day worst-case. Sojourn instead uses OSV's
per-ecosystem **`modified_id.csv`** delta-fetch:

1. `GET https://storage.googleapis.com/osv-vulnerabilities/<ECOSYSTEM>/modified_id.csv`
   per ecosystem the user has installed packages in.
2. Sojourn stores `last_fetch_timestamp` per ecosystem; selects only IDs
   modified since.
3. Resolve IDs to records via the GCS bucket
   (`<base>/<ECOSYSTEM>/<ID>.json`) or `api.osv.dev/v1/vulns/<ID>`.
4. Cross-reference locally against the installed package list (from
   `mpm backup` snapshot in memory).

Cost per refresh drops from O(installed-packages) (200+ POSTs) to
O(new-vulns-since-last-fetch) (typically <10 records).

Settings: `network.osv_refresh_interval_hours` (default 6),
`network.osv_modified_id_base_url`, `network.osv_endpoint` —
see [reference/settings.md](settings.md).

## Scheduling mechanism

**Hybrid: LSUIElement menu bar app + `NSBackgroundActivityScheduler` for
in-process refresh; optional `SMAppService.agent(plistName:)` LaunchAgent
for users who want checks to continue when the app is quit.**

Two scheduled tasks:

- `app.bizarre.sojourn.refresh-outdated` — `mpm outdated` cadence,
  hourly default (`mpm.outdated_refresh_hours`).
- `app.bizarre.sojourn.refresh-advisories` — OSV delta-fetch, 6-hourly
  default (`network.osv_refresh_interval_hours`).

Justification: `NSBackgroundActivityScheduler` routes through DAS/CTS,
respects App Nap and thermal/battery state, and is the documented Apple
path. Running as LSUIElement (menu bar) gets us visibility (user sees the
icon, reducing surprise) plus App Nap benefits. Precedent: Cork (menu bar
extra), Ice (LSUIElement), homebrew-autoupdate tap (launchd agent with 24h
`StartInterval`).

Background-only LaunchAgent is opt-in. Uses `SMAppService.agent` (macOS 13+,
clean install/uninstall) with `StartCalendarInterval` (avoids
wake-from-sleep burst firing), `LowPriorityIO`, `ProcessType=Background`,
and an `--ac-only` gate in the helper binary mirroring
homebrew-autoupdate's Jan 2025 pattern.

**Notification flow**: on discovering eligible updates past cooldown, post
a `UserNotifications` banner grouped by ecosystem. Action buttons: *Review*
(open Sojourn), *Install all safe now*, *Snooze 7d*. Never install without
consent outside tier A.
