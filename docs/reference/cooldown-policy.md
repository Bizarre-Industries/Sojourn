# Auto-update safety / cooldown policy

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
[reference/managers/README.md](managers/README.md).

## Advisory-aware cooldown

If OSV / GHSA has a published advisory for the **old** version, bypass the
cooldown and update. Sojourn fetches OSV via `api.osv.dev` on its daily
refresh.

## Scheduling mechanism

**Hybrid: LSUIElement menu bar app + `NSBackgroundActivityScheduler` for
in-process daily refresh; optional `SMAppService.agent(plistName:)`
LaunchAgent for users who want checks to continue when the app is quit.**

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
