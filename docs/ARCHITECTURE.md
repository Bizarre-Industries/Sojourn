# Sojourn — architecture and design document (v0.1)

Codename: **Sojourn**. Product shape: native macOS 14+ SwiftUI app, notarized DMG, GPL-2.0-or-later subprocess wrapper around `mpm`, `chezmoi`, `git`, and `gitleaks`. This document resolves the open design questions, picks sides, and is the working spec.

---

## 1. Code name selection and rationale

**Sojourn.** A temporary stay in a place — exactly what a Mac setup is. Evokes carry-across-time without being cliché.

Availability cleared the bar the other candidates did not:
- **GitHub**: several small unrelated repos (`paulhibbing/Sojourn` R package, `esmevane/sojourn` JS scaffold, `MelroseCS/sojourn` dormant iOS SDK, `smudge/sojourn` Rails gem). No dominant project; the `github.com/sojourn` org appears available, with `sojourn-app` / `getsojourn` / `sojournhq` as clean fallbacks.
- **npm**: no dominant `sojourn` package owns mindshare.
- **Trademarks**: USPTO filings are Sojourn International (surfboard accessories) and Sojourn Solutions (MarTech consulting). Neither class 9 nor class 42 (computing/SaaS). Low enforcement risk for an indie OSS dev tool.
- **Mac App Store**: no app currently named Sojourn in the search results.

Knockouts for the record: **Relay** (Facebook GraphQL), **Lantern** (getlantern proxy), **Cairn** (shipping Mac hiking-safety app + Game Bakers video game), **Ember** (Ember.js TM by Tilde), **Mantle** (GitHub's Obj-C JSON framework — fatal in Apple-dev mindshare), **Passage** (1Password's passkey product), **Atlas** (MongoDB), **Tessera** (active Mac art-gallery app + Brompton LED processor + TM-holding patent company), **Beacon/Anchor** (too generic). **Kindling** is the acceptable runner-up (npm slot already used by a small scaffold tool, 8 letters). **Skein** is tempting but collides with Schneier's Skein hash function and two "Skein" dev consultancies.

Caveat: `sojourn.com` apex is almost certainly taken; do a WHOIS pass before settling on a domain. `sojourn.app` / `sojourn.dev` / `getsojourn.com` are acceptable fallbacks and codenames don't require the apex. This is a codename, not a final brand — if marketing ever needs a rename, fine.

---

## 2. Product summary

**Sojourn is a native macOS app that carries your Mac setup — apps, packages, shell configs, and app preferences — across machines and across time.** It wraps `mpm` and `chezmoi` behind a GUI aimed at users who don't want to learn Nix or write Go templates. Explicit push/pull between machines, git-backed rollback of every change, scheduled package updates with a supply-chain-attack cooldown, and automatic cleanup of dotfile cruft from uninstalled tools. Time Machine for the parts of your Mac that Time Machine doesn't actually restore well.

---

## 3. Competitive landscape findings

The market splits into four archetypes; none cover Sojourn's scope.

**Brew-GUI archetype** (Cork, Applite, Brewer X, Cakebrew, Latest, MacUpdater, CleanMyMac). Packages only. Cork (buresdv, v1.7.4 Mar 2026, ~4.4k★, GPL-3 with paid binaries via Paddle at €25, source is open — **Commons Clause claim in the brief could not be verified**; the LICENSE file appears to be plain GPL-3). Applite (milanvarady, v1.3.1, MIT, free, explicitly refuses to grow past casks — "too technical"). Brewer X ($49 one-time, proprietary). **Cakebrew is dead** (v1.3, March 2021, owner confirmed no plans). **MacUpdater was discontinued 2026-01-01**, now free-frozen, DB server running only through year-end. CleanMyMac is a cleaner, not a setup tool. Latest (mangerlahn) tracks Sparkle + MAS apps only, low coverage.

**Dotfile-CLI archetype** (chezmoi v2.70.2, dotbot, yadm, rcm, stow, Mackup). chezmoi is the technical winner and Sojourn's backend. Mackup, the incumbent for app-prefs, has been **effectively broken since Monterey**: its own README now ships a WARNING banner that link mode destroys preferences on Sonoma+. PR #2085 added copy mode as a fallback, but it is still not a live sync. Last release 0.8.43, March 2025 — low-velocity maintenance, not abandoned. This is the biggest open wound for non-nerds.

**Declarative / Nix archetype** (nix-darwin moved to `nix-darwin/nix-darwin` org, home-manager, Determinate Systems). The only existing tools that genuinely unify packages + dotfiles + macOS defaults. Steep learning curve, Nix language, flakes. Determinate Systems has **no consumer Mac GUI** as of v3.13.2 (Apple Silicon only now). The addressable market for nix-darwin caps at the top 2% of developers.

**Adjacent AI-terminal archetype** (Warp, Amazon Q Developer CLI). Warp has Settings Sync (Beta) but it syncs only **Warp's own** settings and documents shell-dotfile incompatibilities. Amazon Q (née Fig, sunset September 2024) is CLI autocomplete. Neither competes.

**Closest near-peer**: OpenBoot, a TUI that claims to capture and restore brew packages, dotfiles, shell config, and macOS prefs. Small project, not GUI. Direct confirmation that the thesis is valid.

**Strong direct signal**: April 2026 HN thread "Show HN: It's 2026 and setting up a Mac for development is still mass googling" explicitly says: *"Brewfile handles packages but not your shell. chezmoi handles dotfiles but not packages. nix-darwin handles everything but good luck onboarding a junior with it. Nothing just does the whole thing."*

**Gap**: no product unifies packages + dotfiles + app-prefs + explicit cross-machine push/pull in a native Mac GUI for the mainstream developer. Sojourn fills it.

---

## 4. High-level architecture

```mermaid
flowchart LR
  UI[SwiftUI UI Layer<br/>3-pane window + MenuBarExtra] --> Store[AppStore<br/>@Observable root]
  Store --> Jobs[JobRunner<br/>async Tasks + LogBuffer]
  Jobs --> Services
  subgraph Services[Service actors]
    BrewSvc[BrewService]
    MPMSvc[MPMService]
    ChezSvc[ChezmoiService]
    GitSvc[GitService]
    PrefSvc[PrefService]
    ScanSvc[SecretScanService]
    BootSvc[BootstrapService]
    SchedSvc[SchedulerService]
  end
  Services -->|swift-subprocess| CLI[User's CLI binaries]
  CLI --> brew[/opt/homebrew/bin/brew]
  CLI --> mpm[mpm]
  CLI --> chezmoi[chezmoi]
  CLI --> git[/usr/bin/git]
  CLI --> defaults[defaults]
  CLI --> gitleaks[gitleaks - bundled]
  Store --> Persist[Settings + cache<br/>Application Support]
  GitSvc --> Remote[(User's git remote<br/>GitHub/GitLab/self-hosted)]
```

Layering rules:
- **UI never calls Process directly.** It reads `AppStore` state and dispatches intents to `JobRunner`.
- **Services are actors.** Each wraps exactly one CLI. They return typed values and optionally yield `AsyncThrowingStream<OutputChunk, Error>`.
- **Every subprocess invocation is a `Job`** with id, start time, termination status, and a line-buffered log. Jobs are cancellable.
- **No library linking to GPL backends.** mpm is invoked only via `Process` / `swift-subprocess`; chezmoi is invoked the same way. This is the licensing firewall (see §13).

---

## 5. Backend integration details

### 5.1 mpm (v6.3.0+, Python-based, PyInstaller-frozen standalone binary available)

Invocation contract. mpm 6.x renamed its output flag from `--output-format` back to `--table-format`. This is a real gotcha — the brief had the 5.x flag. Pin to 6.x and use `--table-format json`.

Subcommands actually usable:
- `mpm --table-format json installed` — returns `{manager_id: {errors[], id, name, packages: [{id, installed_version, name|null}]}}`. `name` is frequently `null` (pip, vscode). Always fall back to `id` for display.
- `mpm --table-format json outdated` — same shape with `latest_version` added. Per-manager `errors[]` is the partial-failure channel; surface it in the UI rather than failing the whole operation.
- `mpm --table-format json search <q>` — same per-manager shape. `pip` does not implement search, so its errors array fires on every cross-manager search — this is normal.
- `mpm --table-format json managers` — manager inventory with CLI path, version, platform compatibility.
- `mpm backup [FILE]` — **outputs TOML, not JSON**. Brewfile-style. Sojourn's snapshot format *is* this file, committed into the repo as `packages.toml`.
- `mpm restore <FILE.toml>` — imperative, no JSON output.

Latency budget: **`mpm outdated` is unbounded**. Dominant cost is brew's JSON API auto-refresh (default was 1 day, **PR #21262 bumped to 7 days**, merged Dec 2025). Warm caches: 20s across all managers. Cold: 3+ minutes. mpm's own `-t/--timeout` default is 10 minutes per CLI call — too long for UX. Override with 90s per call.

Parallelization: mpm invokes managers sequentially in-process. Sojourn fans out per-manager calls (`mpm --brew outdated`, `mpm --cask outdated`, …) in parallel from the Swift layer and aggregates. Each fires its own `Job` with a spinner; partial results stream.

Supported managers on macOS (2026): reliable = brew, cask, mas, pip, pipx, npm, gem, composer, cargo, yarn, vscode, uvx. **pnpm is not supported**; shell out directly or file a PR. cargo has no native outdated; use `cargo install --list` for installed only.

Installation strategy (see §9): prefer `brew install meta-package-manager` when brew is present; fall back to the **pre-built Nuitka-compiled standalone binaries** (`mpm-macos-arm64.bin`) from GitHub releases. Do not bundle mpm inside `Contents/Resources/` — it updates more often than Sojourn, and shipping a frozen Python interpreter inside the app complicates notarization.

Risk: single-maintainer project. README explicitly: *"maintained by only one person."* Mitigation: keep the integration thin; any subcommand could in principle be reimplemented against the underlying managers directly. Preserve that option.

### 5.2 chezmoi (v2.70.2, MIT, single static Go binary)

Machine-readable output:
- `chezmoi managed --format=json` — stable JSON. Use this for the file tree UI.
- `chezmoi data --format=json` — full template data dict, useful to populate the per-machine template-variable editor.
- `chezmoi dump --format=json` — target state for a set of files.
- `chezmoi dump-config --format=json` — effective merged config. Note: `cat-config` has no JSON mode (the brief asked — use `dump-config`).
- `chezmoi status` — **not JSON, git-status-style plaintext**. Parse with `^([ ADMR])([ ADMR]) (.+)$`. The MM vs `M ` distinction is under-documented (issues #2635, #4180); treat as advisory.
- `chezmoi diff` — **not JSON, hybrid unified-diff + pseudo-shell commands** (symlinks, scripts, dir modes). Issue #677 still open. Sojourn renders it verbatim in a terminal-style pane; it does not attempt structured diff. Always pass `--no-pager --color=false` when capturing.
- `chezmoi execute-template` — useful for previewing templated output in the editor.
- `chezmoi verify` — exit code signal only. Good for a green/red status-bar dot.

Behaviors that will bite the UI:
- `chezmoi apply` is **interactive by default** if the target was modified since last write. Sojourn runs `status` + `diff` first, shows the user a diff-and-resolve pane, then invokes `apply --force` with explicit consent.
- `diff`/`status`/`verify` take a read lock. Serialize polling.
- Age builtin does not support passphrases, symmetric, or SSH keys — those need the external `age` binary. Sojourn bundles the external `age` binary; it's a tiny Go executable with MIT license.

Encryption: chezmoi's age integration is the right answer for secrets. Config snippet committed by Sojourn:

```toml
encryption = "age"
[age]
identity = "~/.config/chezmoi/key.txt"
recipient = "age1..."
```

The key is *not* committed to the repo. Bootstrap on a new machine: Sojourn prompts for the recipient public key, generates the identity locally via `chezmoi age-keygen`, and walks the user through adding the new recipient to the repo so the old Mac can re-encrypt for the new one on next push. (v1 allows only one active writer at a time; multi-recipient support defers to v2.)

chezmoi v2.70.2 switched to `betterleaks` for internal secret detection on `chezmoi add`. It warns but does not auto-encrypt. Sojourn layers its own gitleaks scan on top (see §5.3) because betterleaks is embedded and the user has no control over rules from the app layer.

Latency: sub-second for status/managed/data; 1–5s for diff; `apply` is dominated by user scripts and can take minutes. Off-main-thread always.

### 5.3 Secret scanning: gitleaks (bundled)

gitleaks v8.30.1 (March 2026), MIT, ~8 MB static Go binary. Ships in `Contents/Resources/bin/gitleaks`, re-signed with Sojourn's Team ID under `--options=runtime`, stapled as part of the outer notarization.

Rejected alternatives:
- **trufflehog**: AGPL-3.0. Flag for any bundling — the network-disclosure obligation is narrow for a local desktop but adds legal surface area. Also slower, more false positives without verification (which would require network egress — privacy regression).
- **detect-secrets**: Python. Requires interpreter. Large (~30–60 MB via PyInstaller). Yelp maintenance is effectively cold (v1.5.0, no new tag since 2023/24, dependabot-only commits).

gitleaks is invoked as `gitleaks dir --staged --no-git --report-format json` on pending diffs before each auto-commit. Rules in a bundled `.gitleaks.toml` with conservative defaults; user can add allowlists per repo.

chezmoi's built-in age encryption covers secret *storage*, not secret *detection*. gitleaks covers detection. These are complementary, not overlapping.

### 5.4 Git: shell out to `/usr/bin/git`

No SwiftGit2, no SwiftGitX, no libgit2. System `git` always exists on macOS (the `/usr/bin/git` shim triggers Xcode CLT install if missing, which Sojourn's bootstrap handles explicitly anyway). This is what GitHub Desktop, Fork, Tower, Sourcetree, Sublime Merge all do.

Reasons, ranked:
1. Dotfile repos are tiny. No libgit2 perf advantage.
2. User's `.gitconfig` probably has commit signing, credentials, SSH agent, LFS — shelling out respects all of it for free. `git-credential-osxkeychain` is default on macOS and handles Keychain auth without Sojourn writing a single line.
3. No notarization burden of bundling libgit2 + OpenSSL + libssh2.
4. libgit2 lacks Git LFS, SSH agent forwarding, SSH signing support is partial.

Porcelain flags used: `git status --porcelain=v2 --branch -z`, `git log --pretty=format:'%H%x00%an%x00%at%x00%s' -z`, `git diff --numstat -z`. Null-terminated. Safer than newline-split.

Authentication (§8): both OAuth device flow (for GitHub new users) and BYO remote (the default, works for any host).

---

## 6. Sync model spec

**Explicit push/pull, one active writer at a time.** Not continuous bidirectional sync. Conflict handling on concurrent writes is deferred to v2 and loudly flagged in UI.

### Model
- Each Mac has a `machine_id` (UUID generated on first run, stored in `~/Library/Application Support/Sojourn/machine.json`).
- The git repo stores per-machine metadata under `.sojourn/machines/<id>.toml`: hostname, human name, last push timestamp, last push commit SHA, chezmoi age recipient.
- One machine is marked `active_writer` in `.sojourn/active.toml`. Only the active writer may push; others must pull first and explicitly take the writer lock.

### Operations
- **Push** (user clicks Push): Sojourn captures current state (`mpm backup` → `packages.toml`; `chezmoi re-add` for any user-modified managed files; `defaults export` for each tracked preference domain); runs gitleaks; shows a diff; user confirms; commits; pushes; updates `.sojourn/active.toml`.
- **Pull** (user clicks Pull): `git fetch`; show inbound diff; user confirms; `git pull`; `mpm restore packages.toml` (with cooldown and tier gating, §7); `chezmoi apply` with `--force` after user-confirmed diff; `defaults import` for each tracked domain (round-tripped through cfprefsd, §8).
- **Take writer lock**: explicit action. Writes a new `active.toml` in a commit. Prevents another Mac from pushing without also pulling and taking the lock. This is cooperative, not authoritative — git has no locking — but it catches the 95% case of a user forgetting to pull first.

### Per-machine overrides via chezmoi templates
chezmoi templates get us most of the way. The app exposes a "Per-machine overrides" pane that edits `.chezmoidata.toml` and, per file, offers to wrap a section in `{{ if eq .chezmoi.hostname "work-mbp" }}…{{ end }}`. The template language is Go text/template; the UI hides this behind a form ("Apply this block only on: [machine picker]") and generates the boilerplate.

Package overrides: `packages.toml` sections are already per-manager. Sojourn extends the schema with optional per-machine gating:

```toml
[brew]
ripgrep = "*"
fd = "*"

[brew.only."work-mbp"]
slack = "*"

[brew.exclude."personal-mini"]
docker = "*"
```

The app reconciles this to `mpm restore` calls on a per-machine computed subset. This is a Sojourn-side feature; the underlying `mpm backup`/`restore` format is unchanged (the gating keys live in separate tables, not in mpm's own).

### Conflict handling (v1)
- On pull, if there are uncommitted local changes, refuse and show the user the diff. User can stash (Sojourn commits a WIP branch) or discard.
- On push, if remote has diverged, refuse and require pull. No auto-merge.
- Garbage collection: Sojourn keeps a local `.sojourn/backups/` of pre-operation snapshots for rollback, 30-day retention.

v2 will add: last-writer-wins with per-file metadata timestamps, three-way merge via `git merge-file` for text, side-by-side conflict resolution for plist diffs.

---

## 7. Auto-update safety model

**Default cooldown: 7 days.** The 72-hour figure from 2020-era writeups is now too aggressive given weekend publish windows. 7 days is the 2026 consensus (Datadog, Renovate's `config:best-practices` for npm defaults to 3 days but adds weekend padding discussion; Dependabot and Mend converge around 7; Snyk hardcodes 21; uv and Renovate both support configurable durations).

Evidence base — incidents in 2024–2026 with short exposure windows that a 7-day gate blocks outright:
- **axios 1.14.1 / 0.30.4** (Mar 31, 2026) — malicious 2–4 hours.
- **Shai-Hulud 1** (Sep 15, 2025, 187 packages incl. @crowdstrike/*) — self-replicating worm.
- **Shai-Hulud 2.0** (Nov 24, 2025, 796 packages, 20M weekly downloads).
- **s1ngularity / Nx** (Aug 26–27, 2025) — SSH key + GitHub token exfiltration, 4–5 hour window.
- **chalk/debug/tinycolor phishing** (Sep 2025) — ~2B weekly downloads affected.
- **ua-parser-js** (Oct 2021, ~4h), **Solana web3.js** (Dec 2024, ~5h), **Ledger Connect Kit** (Dec 2023, ~5h).

The **xz backdoor** (CVE-2024-3094) is the flagship case where no cooldown helps — multi-year maintainer infiltration. User-facing copy should say so to avoid false confidence.

### Per-ecosystem tiers

| Tier | Ecosystem | Default behavior | Cooldown |
|---|---|---|---|
| A safest | Mac App Store (`mas`) | Auto | 0 |
| B safe | Homebrew formulae | Auto | 7 days |
| B safe | `cargo` | Auto | 7 days |
| C moderate | Homebrew casks | User prompt | 3–7 days |
| C moderate | Pinned `pip`/`uv` project deps | Auto | 7 days |
| D risky | Global `pip`/`pipx` | User prompt | 7 days |
| E high-risk | Global `npm` | **Never auto-update silently** | 14 days |

Hard rule: **never auto-run an install that would execute `preinstall` / `postinstall` / build scripts without user confirmation**, even inside cooldown.

Advisory-aware cooldown: if OSV/GHSA has a published advisory for the **old** version, bypass the cooldown and update. Sojourn fetches OSV via `api.osv.dev` on its daily refresh.

### Scheduling mechanism

**Hybrid: LSUIElement menu bar app + `NSBackgroundActivityScheduler` for in-process daily refresh; optional `SMAppService.agent(plistName:)` LaunchAgent for users who want checks to continue when the app is quit.**

Justification: `NSBackgroundActivityScheduler` routes through DAS/CTS, respects App Nap and thermal/battery state, and is the documented Apple path. Running as LSUIElement (menu bar) gets us visibility (user sees the icon, reducing surprise) plus App Nap benefits. Precedent: Cork (menu bar extra), Ice (LSUIElement), homebrew-autoupdate tap (launchd agent with 24h `StartInterval`).

Background-only LaunchAgent is opt-in. Uses `SMAppService.agent` (macOS 13+, clean install/uninstall) with `StartCalendarInterval` (avoids wake-from-sleep burst firing), `LowPriorityIO`, `ProcessType=Background`, and an `--ac-only` gate in the helper binary mirroring homebrew-autoupdate's Jan 2025 pattern.

**Notification flow**: on discovering eligible updates past cooldown, post a `UserNotifications` banner grouped by ecosystem. Action buttons: *Review* (open Sojourn), *Install all safe now*, *Snooze 7d*. Never install without consent outside tier A.

---

## 8. Plist / app-preference sync strategy

**The brutal truth: symlinking plists is dead.** Mackup's own README ships the warning. This is not a macOS 14 change alone — it's the combination of Sonoma's hardened container TCC, more aggressive `cfprefsd` flushing, and the long-standing fact that `cfprefsd` rewrites plist files via atomic rename (which replaces symlinks with regular files).

Sojourn's strategy has four layers.

**Layer 1: transport is `defaults export` / `defaults import`.** Round-trips through `cfprefsd`, updates its in-memory cache, survives sandbox boundaries. This is the only first-class Apple-supported path. Sojourn runs `defaults export com.foo.bar ~/Library/Application Support/Sojourn/preferences/com.foo.bar.plist` per tracked domain on push, and the reverse on pull. Preferences are committed as XML-format plist (runs `plutil -convert xml1` before commit) so git diffs are legible.

**Layer 2: domain classification.** Every tracked preference is tagged with a class:
- *plain dotfile* (e.g., `~/.zshrc`) — chezmoi-managed, git-diffable, no cfprefsd involvement.
- *unsandboxed plist* (e.g., `~/Library/Preferences/com.googlecode.iterm2.plist`) — `defaults export/import`.
- *sandboxed plist* (e.g., Safari's container) — requires Full Disk Access; Sojourn refuses to sync these without FDA granted (and uses `/Library/Preferences/com.apple.TimeMachine.plist` read as the canary probe, per Apple DevForums thread 114452).
- *Application Support blob* (e.g., keymap files) — rsync copy with no cfprefsd round-trip.

The Mackup `applications/` registry (GPL-3, ~500+ .cfg files) is **seed material, not verbatim truth**. A significant fraction of its entries point at paths that will trip cfprefsd or Containers TCC. Sojourn forks the registry, re-classifies each entry, and maintains it as its own data file under `data/applications/*.toml`. License the fork as GPL-3 (matching Mackup) and credit upstream. Do not vendor the live Mackup repo.

**Layer 3: safe-copy discipline.** For domains where the target app is running, Sojourn quits-or-prompts the app before import (AppleScript `tell application "id:com.foo" to quit`), runs `killall cfprefsd` with explicit user consent if needed, performs `defaults import`, then relaunches. Power users can toggle off the quit-and-relaunch and accept partial sync.

**Layer 4: don't require FDA by default.** Unsandboxed plists and the standard user dotfiles cover 80% of what users want to sync. Full Disk Access is prompted only when the user explicitly asks to sync a sandboxed app's preferences. This keeps the onboarding experience clean; power users pay the TCC cost only when they need it.

**What Sojourn does not attempt**: binary plist structural diff/merge (beyond `plutil -convert xml1` round-trip for storage), key-level selective sync within a plist (deferred to v2), apps that use keychain-backed preferences (e.g., 1Password's license), or anything in `~/Library/Group Containers` without FDA.

---

## 9. Dependency bootstrap flow

First-run state machine in `BootstrapService` (actor):

```
.unknown
  -> .probingSystem               // parallel: xcode-select -p, locate brew/git/mpm/chezmoi/age/gitleaks
  -> .reportingStatus             // present inventory
  -> .awaitingUserConsent         // single "Install missing" confirmation
  -> .installingCLT               // xcode-select --install; observe until done
  -> .installingBrew              // .pkg installer with Authorization prompt
  -> .installingMpm               // brew install meta-package-manager, or standalone binary
  -> .installingChezmoi           // brew install chezmoi, or curl script, or direct binary
  -> .ready
  -> .failed(Error)               // per-step retry/skip UI
```

**Homebrew install**: do not use `NONINTERACTIVE=1 curl | bash`. That flag only skips the Y/N prompt — it still invokes `sudo`, which is a dead-end for a GUI that can't cache a sudo ticket. Instead, **download the official signed `.pkg` from the latest Homebrew release**, verify its code signature (Team ID as published), and hand it to `/usr/sbin/installer` or `open -W`. The user gets one native macOS Authorization dialog. Clean, one click, no terminal.

**mpm**: prefer `brew install meta-package-manager`. Fall back to the Nuitka-compiled standalone binary from GitHub releases (`mpm-macos-arm64.bin` or `mpm-macos-x64.bin`), verify SHA-256, `xattr -d com.apple.quarantine`, install to `~/Library/Application Support/Sojourn/bin/mpm`. Do not bundle.

**chezmoi**: prefer `brew install chezmoi`. Fall back to the `get.chezmoi.io` script (non-interactive by default) or direct binary download with cosign-verifiable checksums. chezmoi is signed + notarized as of 2024+.

**gitleaks**: bundled inside the app at `Contents/Resources/bin/gitleaks`. Re-signed and notarized as part of Sojourn.

**age**: bundled (small, MIT, needed for chezmoi's external age features).

**Secondary managers (npm, pip, cargo, gem)**: on-demand. First time the user tries to sync an `npm`-tracked package, Sojourn offers `brew install node` in a sheet. Installing them all upfront wastes 1–2 GB and many minutes for users who won't use them.

**Detection is hardcoded candidates, not `which`**: app-context `PATH` is LaunchServices-minimal (`/usr/bin:/bin:/usr/sbin:/sbin`), so `which brew` fails on Apple Silicon. Hardcode: `/opt/homebrew/bin/brew`, `/usr/local/bin/brew`, `~/.cargo/bin`, `~/.local/bin`, `~/go/bin`, etc. Cache results in `Settings.toolLocations`. Expose a Paths settings pane for override.

UX gating: only consent, CLT installer, and the brew `.pkg` Authorization prompt require foreground user action. Everything else streams stdout into a bootstrap log view; user can minimize to menu bar.

---

## 10. Dotfile cleanup / cruft detection

No existing tool does this for dotfiles specifically. `~/Library/**` orphan detection is solved by Pearcleaner (active SwiftUI, open source, 5.4.3), AppCleaner (12+ years old, still works), PureMac, MyMacCleaner. All of them work by bundle-ID reconciliation against `~/Library`. None look at `~/.foo` dotfiles, because dotfile names rarely match bundle IDs.

Sojourn's approach:

**Primary signal: reconcile `~/.foo`-style configs against a tool-presence inventory.** Ship a curated mapping `data/dotfile_owners.toml`:

```toml
".zshrc" = { tool = "zsh", source = "system|brew" }
".gitconfig" = { tool = "git", source = "system|brew" }
".aws" = { tool = "awscli", source = "brew|pip" }
".rbenv" = { tool = "rbenv", source = "brew" }
# ...
```

For each entry, mark orphan if none of the tool's sources are installed (checked against `brew list`, `pipx list`, `$PATH` probe, mpm-managed registry).

**Secondary gating signals** (reduce false positives — none are auto-delete):
- Shell history grep (`grep -l basename ~/.zsh_history ~/.bash_history`) within 180 days -> keep.
- `com.apple.lastuseddate#PS` xattr within 180 days -> keep.
- Parent dir mtime within 30 days -> keep.

**APFS atime is not usable as authoritative "last used."** Default mount is non-strict atime; Quick Look updates it, some API paths do not, Spotlight/Time Machine can tick it. Use only as a tiebreaker. Document this so sophisticated users don't ask why atime is ignored.

**Also handle `~/Library/**`** using bundle-ID reconciliation (the Pearcleaner model): enumerate `/Applications`, `~/Applications`, cask artifacts, MAS receipts (`/Library/Application Support/App Store/receipts/`); extract `CFBundleIdentifier`; match against `~/Library/{Preferences, Application Support, Containers, Group Containers, Caches, LaunchAgents, Saved Application State}`; candidates with no owning app are orphans.

**Classification per orphan**:
- *safe*: caches, saved app state.
- *review*: preferences, Application Support.
- *risky*: containers (may hold user documents), LaunchAgents, keychain-adjacent files.

**Actions**:
- Always move to Trash (`NSFileManager.trashItem`), never `rm`. Trash is the undo log for 10 most recent actions.
- Also keep an SQLite `deletions.db` under Application Support with path, checksum, timestamp, and reason — so a user can reconstruct or audit.
- No auto-delete. Always user confirmation. The Mac cleanup UX pattern is well-understood here (AppCleaner, Pearcleaner).

---

## 11. SwiftUI app structure

### Platform and dependencies
- macOS 14+ (Sonoma and later). macOS 14 is ~18 months old by v1 ship; this is an acceptable floor given the target audience.
- Swift 6.1+ toolchain.
- SPM dependencies: `swiftlang/swift-subprocess` (pin `.upToNextMinor(from: "0.4.0")`); `orchetect/MenuBarExtraAccess` (escape hatch for `MenuBarExtra`). That's it. No TCA, no SwiftGit2, no SwiftShell, no libgit2.

### State management: raw `@Observable`, not TCA

Observation framework (macOS 14+) solves the problems TCA was invented for. TCA adds 24-releases-in-a-year churn, macro-property-wrapper friction, a giant-state-struct pattern that fights SwiftUI at scale, and collaborator ramp. Sojourn's state is almost entirely derived from parsed JSON subprocess output — TCA's action/reducer ceremony is low-value here.

Root store:
```swift
@Observable final class AppStore {
    var settings: Settings = .load()
    var managers: [ManagerID: ManagerSnapshot] = [:]
    var history: [HistoryEntry] = []
    var bootstrapState: BootstrapState = .unknown
    var activeJobs: [JobID: Job] = [:]
    var lastError: AppError?
    var toolInventory: ToolInventory = .empty
}
```

Injected once at `App`, read with `@Environment(AppStore.self)`. Use `@Bindable` for two-way bindings into UI. Beware Jesse Squires' `@State + @Observable` initialization gotcha: always create the root store at app level, never at view level.

### Subprocess execution: `swift-subprocess`

`try await run(.path(url), arguments: [...], output: .string(limit: 10_000_000))` for collected results; the closure-based overload with `AsyncBufferSequence` for streaming. Pin minor versions because it's pre-1.0 (0.4.x as of Sep 2025; requires Swift 6.1). Fallback for future macOS SDK compatibility: raw `Process` + `Pipe` + `AsyncStream`.

Known gotchas to handle in `SubprocessRunner`:
- **Block-buffered stdio** when child is not a TTY. Mitigate by wrapping long-running commands with `script -q /dev/null <cmd>` to get a PTY, or accept buffered output for tools that flush appropriately.
- **`AsyncStream` is single-consumer**. Fan out through a broadcaster inside `LogBuffer`.
- **Swift 6 strict concurrency**: `Pipe.readabilityHandler` is not actor-isolated. Keep captures minimal; send `Data` via continuation; don't touch `@MainActor` state inside.
- **64 KB pipe backpressure**. Always read; never let a pipe back up.

### Streaming output to UI

Pipeline: bytes -> line splitter (actor) -> ANSI SGR parser (strip to `AttributedString`) -> ring-buffered `@Observable LogBuffer` -> SwiftUI `LazyVStack` of `AttributedString` rows with `.monospaced()` and `.textSelection(.enabled)`.

Strip ANSI by default. Ship a `SwiftTerm`-based full-VT100 pane as an optional "Advanced" tab for users who want to run arbitrary brew commands manually. SwiftTerm is used in Secure Shellfish and La Terminal; well-supported.

### Menu bar: `MenuBarExtra(.window)` + `MenuBarExtraAccess`

`MenuBarExtra` is the canonical 2026 path. `.window` style gives a full SwiftUI popover (list of active jobs, quick upgrade, reveal main window). `MenuBarExtraAccess` is a thin extension that exposes the underlying `NSStatusItem` and a programmatic show/hide binding — widely adopted workaround for `MenuBarExtra` limits.

### Main window: `NavigationSplitView` 3-pane

- **Left sidebar**: source picker — Packages, Dotfiles, Preferences, History, Machines, Settings.
- **Middle list**: context-sensitive (e.g., manager list for Packages; managed-file tree for Dotfiles).
- **Right detail**: item detail + actions + (when running) embedded log pane.

### Scheduling: `NSBackgroundActivityScheduler` in-process

See §7 for the full spec. Scheduler activity id `app.bizarre.sojourn.refresh-outdated`, interval 1h, tolerance 15m, QoS `.utility`.

### Module breakdown

```
App/
  SojournApp.swift             // @main, WindowGroup + MenuBarExtra scenes
  AppStore.swift               // @Observable root
  Settings.swift               // Codable, persisted
Services/
  SubprocessRunner.swift       // wraps swift-subprocess
  BrewService.swift            // actor
  MPMService.swift             // actor; JSON decode
  ChezmoiService.swift         // actor
  GitService.swift             // actor; /usr/bin/git
  PrefService.swift            // actor; defaults export/import, plutil
  SecretScanService.swift      // actor; gitleaks
  BootstrapService.swift       // actor
  GitHubDeviceAuth.swift       // URLSession + Keychain
  ToolLocator.swift            // hardcoded candidate paths
  ToolInventory.swift          // snapshot value type
Jobs/
  JobRunner.swift              // owns Tasks; pipes to LogBuffer
  LogBuffer.swift              // @Observable ring buffer, AttributedString rows
  ANSIParser.swift             // SGR -> AttributeContainer
Scheduling/
  BackgroundActivity.swift     // NSBackgroundActivityScheduler wrapper
Sync/
  SyncCoordinator.swift        // push/pull orchestration
  MachineMetadata.swift        // .sojourn/machines/*.toml
UI/
  MainWindowView.swift         // NavigationSplitView
  MenuBarRootView.swift
  BootstrapView.swift
  LogConsoleView.swift
  PackagesPane.swift
  DotfilesPane.swift
  PreferencesPane.swift
  HistoryPane.swift
  MachinesPane.swift
  SecretPromptSheet.swift
Data/
  applications/*.toml          // Mackup-derived, re-classified
  dotfile_owners.toml          // cruft-detection mapping
  .gitleaks.toml               // default rules
```

### Bundled binaries

`Contents/Resources/bin/`: `gitleaks`, `age`. Both re-signed with Sojourn's Developer ID under `--options=runtime` and stapled as part of outer notarization. Nothing else bundled — brew, mpm, chezmoi all live in the user's `PATH` and are installed via the bootstrap flow. Rationale: Cork, Applite, Pearcleaner all do the same for brew specifically (brew refuses non-default prefixes and self-updates).

---

## 12. Repo structure

Two repos matter: the **app repo** (Sojourn source code) and the **user's data repo** (their personal dotfiles/packages, created by Sojourn on first run).

### App repo: `bizarreindustries/sojourn`

```
sojourn/
|-- README.md
|-- LICENSE                         # GPL-3.0-or-later (see §13)
|-- CLAUDE.md                       # see §16
|-- CONTRIBUTING.md
|-- .gitleaks.toml                  # for sojourn's own CI
|-- .github/
|   |-- workflows/
|       |-- ci.yml                  # build + test + gitleaks
|       |-- notarize.yml            # signed DMG on tag
|       |-- codeql.yml
|-- Package.swift                   # SPM root (for testing + CLI headless tools)
|-- Sojourn.xcodeproj/              # primary build
|-- Sojourn/                        # app target
|   |-- App/
|   |-- Services/
|   |-- Jobs/
|   |-- Scheduling/
|   |-- Sync/
|   |-- UI/
|   |-- Resources/
|   |   |-- Assets.xcassets
|   |   |-- bin/                    # gitleaks, age (re-signed in build phase)
|   |   |-- data/
|   |       |-- applications/       # Mackup-derived registry, GPL-3
|   |       |-- dotfile_owners.toml
|   |       |-- gitleaks.toml
|   |-- Sojourn.entitlements
|   |-- Info.plist
|-- SojournTests/                   # XCTest / Swift Testing
|   |-- Services/
|   |-- Sync/
|   |-- Fixtures/
|       |-- mpm-installed.json      # golden files
|       |-- chezmoi-managed.json
|       |-- gitleaks-report.json
|-- SojournUITests/
|-- scripts/
|   |-- sign.sh                     # codesign bundled binaries
|   |-- notarize.sh
|   |-- make-dmg.sh
|   |-- update-registry.py          # refresh applications/ from upstream Mackup
|-- docs/
    |-- ARCHITECTURE.md             # this document
    |-- BOOTSTRAP.md                # bootstrap flow detail
    |-- LICENSING.md                # IPC-not-linking rationale
    |-- SECURITY.md                 # gitleaks, cooldown, threat model
```

### User's data repo (generated by Sojourn, user-owned)

Sojourn proposes this structure on first push. User's remote, user's name.

```
my-mac/
|-- packages.toml                   # mpm backup output (TOML)
|-- dotfiles/                       # chezmoi source dir (chezmoi source-path)
|   |-- dot_zshrc.tmpl
|   |-- dot_gitconfig.tmpl
|   |-- private_dot_ssh/
|   |   |-- encrypted_id_ed25519.age
|   |-- .chezmoidata.toml
|   |-- .chezmoiignore
|-- preferences/                    # one XML plist per tracked domain
|   |-- com.googlecode.iterm2.plist
|   |-- com.apple.dock.plist
|   |-- ...
|-- .sojourn/
|   |-- machines/
|   |   |-- work-mbp.toml
|   |   |-- personal-mini.toml
|   |-- active.toml                 # current writer
|   |-- version.toml                # repo schema version (migrate on bump)
|   |-- backups/                    # pre-operation snapshots, 30d retention
|-- .gitleaks.toml                  # user's allowlist
|-- .gitignore
|-- README.md                       # generated; "this repo is managed by Sojourn"
```

Critique of the original proposal (the brief had `packages.toml` + `dotfiles/` + `preferences/` + `.machines/`):
- Kept `packages.toml` at root — good, matches mpm's `backup` output 1:1.
- `dotfiles/` is chezmoi's source dir — correct, and chezmoi handles the `dot_` / `private_` / `encrypted_` / `.tmpl` naming conventions.
- `preferences/` is XML plist (converted via `plutil`) per domain — **not** symlinked, not live.
- `.machines/` renamed to `.sojourn/machines/` and wrapped in a `.sojourn/` namespace so the app's metadata is grouped and easy to migrate.
- Added `active.toml` (cooperative writer lock, §6), `version.toml` (schema migrations), `backups/` (rollback).
- Added `.gitleaks.toml` at root so user's allowlists travel with the repo.

---

## 13. Licensing decision

**GPL-3.0-or-later.** With the strict invariant: **mpm is never linked, only invoked via subprocess with JSON IPC.** This invariant is what keeps the license choice live.

Reasoning:

**AGPL-3.0 is correctly rejected.** Sojourn is a desktop app, not a network service. AGPL's §13 adds obligations that don't benefit desktop users. More importantly, **AGPL-3.0 is incompatible with GPL-2.0-only**: if a future architecture change ever linked mpm as a library, the combined work could not be distributed under AGPL-3.0. Locking this out preserves optionality.

**GPL-2.0-or-later** would be trivially compatible with mpm. But it lacks GPL-3's anti-tivoization and patent-retaliation clauses, which matter for a project that will ship signed macOS binaries and depend on the broader Homebrew + chezmoi ecosystem (both MIT/BSD-style, compatible with GPL-3).

**MPL-2.0** is attractive for indie OSS tooling because of its file-scoped weak copyleft — downstream integrators can combine with proprietary code. But the value prop here is *not* wide commercial integration; it's a finished shipping app. MPL-2.0 also doesn't play as cleanly with GPL-2.0 mpm when invoked via subprocess (subprocess IPC keeps them at arm's length regardless, so this is mostly aesthetic). GPL-3-or-later makes the downstream-forking expectations clearer for a copyleft-committed project.

**GPL-3.0-or-later** with explicit IPC-not-linking language in `LICENSING.md`:

- Sojourn is GPL-3.0-or-later.
- Sojourn invokes `mpm`, `chezmoi`, `git`, `brew`, `gitleaks`, `age`, and `defaults` as separate processes, communicating only via command-line arguments, structured output (JSON/TOML), and exit codes. Sojourn does not link any of these as libraries, does not embed their code, and does not share a process address space with them.
- This is the FSF-recognized arm's-length interaction that does not trigger GPL combined-work obligations. See the FSF GPL FAQ on "mere aggregation" and pipes.
- Bundled binaries in `Contents/Resources/bin/` (`gitleaks` MIT, `age` MIT) are distributed alongside Sojourn as permissively-licensed separate works with their source available at their upstream repos. Sojourn's `THIRDPARTY.md` lists each.

The Mackup-derived `applications/` registry is GPL-3; compatible with Sojourn's GPL-3-or-later license and properly attributed.

Risk note: a future decision to swap mpm for a Swift-native package-manager abstraction (hypothetical) would lift the GPL-2-only constraint and allow re-licensing to MPL-2.0 or similar if the project wants broader downstream reuse. GPL-3-or-later preserves the ability to migrate upward (to AGPL, for instance, if Sojourn ever grows a server component).

---

## 14. Risks and unknowns

Technical risks that could kill the project or require major rework, ordered by severity:

1. **`cfprefsd` gets stricter.** Apple could further lock down `~/Library/Preferences` access in a future macOS release (Tahoe 27 is the next wildcard). If `defaults import` starts requiring additional entitlements or fails for unsandboxed callers, Sojourn's whole preference-sync story degrades. Mitigation: classification system (§8) means dotfile+package sync keeps working even if pref sync breaks; watch Apple security guides at each WWDC; have a plan to ship "preferences as declarative `defaults write` scripts" as a fallback.

2. **mpm bus factor.** Single maintainer, self-declared. If kdeldycke stops shipping mpm, Sojourn needs either to fork or to reimplement the per-manager wrappers. Mitigation: keep `MPMService` surface small; each method is thin enough to reimplement against the underlying managers directly within a week of work. Document that in `CLAUDE.md`.

3. **`swift-subprocess` is pre-1.0 and requires Swift 6.1+.** The API could change. Mitigation: wrap it in `SubprocessRunner` so swapping to raw `Process + Pipe + AsyncStream` is an internal refactor.

4. **Homebrew's self-update behavior changes.** The JSON API refresh was 1 day, then 7 days (PR #21262, Dec 2025); `brew outdated` output format flapped in bug #20976 (Nov 2025, unresolved). Parsers break when brew changes output. Mitigation: treat every mpm/brew output as advisory and surface per-manager `errors[]`; don't write tests that hash exact strings.

5. **chezmoi's `diff`/`status` are not stable structured formats.** Hybrid diff (#677) and `MM` vs `M ` ambiguity (#2635, #4180) are unresolved. Mitigation: render `diff` verbatim; parse `status` with a regex but treat it as a display signal only — the ground truth is `chezmoi apply --dry-run` when we actually care.

6. **gitleaks false positives on new-user dotfiles.** Entropy rules fire on base64 UUIDs, test fixtures, example keys. User clicks "Commit anyway" and learns to ignore the prompt. Mitigation: ship conservative rules; verified-provider findings (AWS/GitHub PAT/OpenAI/Stripe live) disable the "Commit anyway" button for 5s and show a red banner.

7. **GitHub Device Flow requires per-app enablement** since March 2022. The OAuth App must have the checkbox ticked, and Apple has no equivalent way to let the app switch dynamically. Sojourn owns and maintains the OAuth App. Mitigation: BYO remote is the default; device flow is opt-in convenience, so if the OAuth App is ever revoked or rate-limited, app core keeps working.

8. **Notarization of bundled Go binaries.** `gitleaks` and `age` are straightforward but each macOS release has broken someone's stapling. Mitigation: re-sign on the Sojourn build machine with `--options=runtime` every release; CI asserts that `spctl --assess --verbose=4 Sojourn.app` passes on a Gatekeeper-clean VM.

9. **Conflict on concurrent writes is deferred to v2.** Two Macs push at the same time -> git conflict, app refuses to pull until user resolves. Mitigation: cooperative `active.toml` writer lock (§6); loud UI messaging; manual conflict resolution via embedded diff pane. Not ideal; not fatal.

10. **TCC / Full Disk Access surface.** Future macOS may gate `~/Library/Application Support` for third-party apps (Sonoma started gating `~/Library/Containers`). Mitigation: minimize FDA asks; only request when the user opts into sandboxed-app pref sync; canary-probe `/Library/Preferences/com.apple.TimeMachine.plist` to detect FDA status.

11. **APFS timestamp semantics are unreliable.** atime isn't authoritative; orphan detection depends on composite signals. Mitigation: never auto-delete; always move to Trash; log every action.

12. **User data loss via buggy `chezmoi apply`**. `--force` overwrites local edits. Mitigation: always pre-snapshot to `.sojourn/backups/` before any destructive operation; retention 30d; undo log.

Unknowns flagged for re-verification:
- Exact status of Cork's license (Commons Clause vs plain GPL-3 + proprietary binaries). The public README describes a paid-binary model; I could not directly audit the LICENSE file. Verify before shipping competitive copy.
- `.com` apex availability for `sojourn` — not checked. WHOIS before publicizing the name.
- Tahoe-specific APFS atime behavior — no public documentation suggests change, but not independently confirmed.

---

## 15. Proposed v1 scope cut

**Ships in v1:**
- Package sync via `mpm` for brew, cask, mas, pip, pipx, npm, cargo, gem (the reliable subset).
- Dotfile sync via `chezmoi` with templating support, age encryption, per-machine overrides.
- App-preference sync for **unsandboxed plists only** — `defaults export/import` round-trip. Seeded from a re-classified Mackup registry.
- Explicit push/pull model with cooperative writer lock.
- BYO git remote (primary). Optional GitHub Device Flow sign-in.
- Auto-update with 7-day cooldown and tier gating, advisory-aware bypass for OSV/GHSA.
- Secret scanning via bundled gitleaks before every auto-commit.
- Orphan detection for `~/Library/**` (bundle-ID reconciliation) and `~/.foo` dotfiles (curated tool mapping).
- First-run bootstrap with signed Homebrew `.pkg` install, mpm/chezmoi via brew.
- Menu bar extra + main window; `NSBackgroundActivityScheduler` daily refresh.
- Notarized DMG distribution. GPL-3.0-or-later.

**Deferred to v2:**
- Sandboxed-app preference sync (requires FDA + more careful cfprefsd choreography).
- Concurrent-write conflict resolution (three-way merge, per-file timestamps).
- `pnpm` support (not in mpm; shell out if demanded).
- Full VT100 terminal pane (the `SwiftTerm`-backed "advanced" tab).
- Headless LaunchAgent (`SMAppService.agent`) for checks when app is quit.
- Windows/Linux (never, per scope decision).
- Mac App Store distribution (sandboxing is incompatible with subprocess invocation of brew/mpm).

**Deferred indefinitely:**
- Cloud backend hosted by Sojourn. Git remote is user's, always.
- Team/org sync. Single-user only.
- Mobile companion.

---

## 16. CLAUDE.md (repo root)

The full `CLAUDE.md` is committed at repo root. See [/CLAUDE.md](../CLAUDE.md) for the current version.

---

*End of document. v0.1, April 2026. Revise after v1 ship; re-verify mpm, chezmoi, Homebrew, macOS Tahoe behaviors before each major release.*
