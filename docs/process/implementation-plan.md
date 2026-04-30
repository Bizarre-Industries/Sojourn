# Sojourn — Full Implementation Plan (v0.1 → v1 → v1.x)

## Context

Sojourn is a macOS 14+ SwiftUI app for cross-Mac setup sync (packages via
`mpm`, dotfiles via `chezmoi`, prefs via `defaults`). As of 2026-04-24 the
repo had complete design docs and skeletal stubs only; phases 0–9 land the
v0.1 → v1 ship. The audit
[process/audit-2026-04.md](audit-2026-04.md) (2026-04-28) added phases
10–14 for v1 → v1.x — the architectural and feature gaps deferred from
v1.

Execution contract: autonomous commits on `main`. Every phase passes
`swift test` + (eventually) `xcodebuild test` + `gitleaks dir` before
commit. Fixture-backed tests mandatory per [CLAUDE.md](../../CLAUDE.md).

Target spec for phases 0–9:
[reference/architecture.md](../reference/architecture.md). Target spec
for phases 10–14: see audit §2, §3, §4 plus the relevant ADRs cited per
phase.

---

## Phase 0 — Xcode project + xcodegen

Generate `Sojourn.xcodeproj` via `xcodegen` with targets Sojourn (app),
SojournTests (Swift Testing), SojournUITests (XCUITest). Add
`project.yml`, `Sojourn/Config/{Debug,Release}.xcconfig`,
`scripts/regenerate-project.sh`. Wire Info.plist, entitlements,
Resources.

## Phase 1 — Core infra

Real `SubprocessRunner` (swift-subprocess + raw Process/Pipe/AsyncStream
fallback, 64KB backpressure, PTY wrap option, cancellation). `JobRunner`
@MainActor @Observable owning Task per Job. `LogBuffer` ring buffer with
broadcaster. `ANSIParser` SGR state machine → AttributeContainer.
`ToolLocator` candidate-path probe + Xcode CLT detection.

**Audit slot-in §2.1.5**: `ToolLocator` uses `mpm locate` first, falls
back to hardcoded candidates. Bake into Phase 1 spec rather than
retrofit.

## Phase 2 — Models + persistence

Models: AutoUpdateTier, Conflict, Snapshot, HistoryEntry, DotfileOwner,
OrphanCandidate, PreferenceDomain, Job (moved). Persistence:
SojournFileCodec (handwritten TOML), BackupsDirectory (30d retention),
AppSupportPaths, SettingsStore, DeletionsDB (SQLite). Extend AppStore.

## Phase 3 — Subprocess service actors

**3a GitService** — `/usr/bin/git` porcelain v2 -z.
**3b MPMService** — mpm 6.x `--table-format json`, parallel per-manager
fanout, 90s timeout.
**3c ChezmoiService** — `chezmoi managed/status/diff/apply` with
`--no-pager --color=false`.
**3d PrefService** — `defaults export/import`, `plutil -convert xml1`,
FDA canary probe, app quit/relaunch.
**3e SecretScanService** — bundled `gitleaks dir --staged --report-format json`,
classifies high-severity (AWS/GitHub PAT/OpenAI/Stripe) with 5s UI
lockout.
**3f BrewService** — signed .pkg install via `/usr/sbin/installer` with
Authorization.
**3g BootstrapService** — state machine per
[explain/bootstrap-state-machine.md](../explain/bootstrap-state-machine.md). **Audit
slot-in §6.5**: configure `merge.command` in
`~/.config/chezmoi/chezmoi.toml` during bootstrap.
**3h GitHubDeviceAuth** — OAuth Device Flow, client_id only,
Keychain-stored token.

## Phase 4 — Sync coordinator + snapshots

`SnapshotService` (per-op backup to
`~/Library/Application Support/Sojourn/backups/<ts>-<op>/`).
`SyncCoordinator` push/pull orchestration per
[reference/sync-model.md](../reference/sync-model.md). `CooldownGate`
with OSV advisory bypass per
[reference/cooldown-policy.md](../reference/cooldown-policy.md).
`BackgroundActivity` with `NSBackgroundActivityScheduler`
(`app.bizarre.sojourn.refresh-outdated`, 1h/15m tolerance).

**Audit slot-in §2.5.1**: write default `.chezmoiignore` boilerplate
(`known_hosts*`, `.DS_Store`, `*.swp`) on first push.

## Phase 5 — Cleanup / orphan detection

`CleanupService` scans dotfiles (via `data/dotfile_owners.toml`) +
`~/Library/**` (bundle-ID reconciliation). Classifies safe/review/risky.
Uses `NSFileManager.trashItem` + DeletionsDB log. Never `rm`. Populate
dotfile_owners registry (~60 entries) and applications registry
(~100 top apps).

## Phase 6 — UI (v0.1 baseline)

Full SwiftUI surface: Sidebar, Packages/Dotfiles/Preferences/History/
Machines/Cleanup panes, OnboardingFlow, PushPullBar,
ConflictResolutionView, SecretFindingsModal (5s lockout), SettingsScene,
MenuBarRootView, BootstrapView, LogConsoleView. Logical-accessibility UI
tests. (Audit GUI gaps §4 land progressively in phases 11–14.)

## Phase 7 — Release pipeline

Real `download-bundled-bins.sh` (gitleaks + age via `gh release download`,
codesign `--options=runtime`). Real sign/notarize/dmg/cask scripts. CI
workflows: ci.yml (swift test + xcodebuild test + gitleaks), notarize.yml
(tag-triggered full release), codeql.yml weekly. MAINTAINERS.md,
docs/reference/third-party.md.

## Phase 8 — Docs expansion

The Phase 8 originally listed `SUPPORTED_MANAGERS.md`, `RELEASE.md`,
`CONFLICTS.md`, `PREFS_DOMAINS.md`. **All shipped + reorganized** under
the Diátaxis tree in the audit-driven docs restructure (Phases 0–5 of
the docs rework, see [redirects.toml](../redirects.toml)).

**Audit slot-in §1.1–§1.3**: doc-drift fixes (module tree, Cork license,
cask cooldown) shipped in the docs restructure.

## Phase 9 — Polish

`.swift-format`, `.swiftlint.yml`, accessibility audit, ASan test run.

---

## Phase 10 — Backend protocol layer (v1.x; promotes ADR-0010)

Audit §3.2 protocols. Introduce:

- `PackageBackend` — `installed()`, `outdated()`, `install(pkgs:)`,
  `remove(pkgs:)`, `upgrade(pkgs:)`. All current `*Service` actors
  (`MPMService`, future `BrewService`/`CaskService`/`MasService`) conform.
- `DotfileBackend` — `chezmoi`-shaped surface; future-proofs alternates.
- `PrefBackend` — `defaults`-shaped surface; future-proofs alternates.
- `SecretBroker` — backs ADR-0011; per-provider actors conform.
- `BackendRegistry` — discovers + dispatches per `ManagerID`. Hybrid:
  protocol-witness for compile-time built-ins, actor-with-discovery for
  runtime plugins.

`JobRunner` and `SyncCoordinator` work against the protocol, not the
concrete actor.

Promotes [decisions/0010-native-brew-keep-mpm.md](../decisions/0010-native-brew-keep-mpm.md)
to Accepted.

## Phase 11 — Module restructure (v1.x)

Audit §3.1. Land the module-level changes:

- §3.1.1 New `Models/` module — value types live in one place. (Already
  added to ARCHITECTURE.md §11 module tree in docs Phase 1.)
- §3.1.2 New `Policy/` module — `CooldownPolicy.swift`,
  `AdvisoryService.swift`, `TierClassifier.swift`. Pure-function policy
  with actor-based I/O.
- §3.1.3 Split `BootstrapService` → `Bootstrap/ToolProbe`,
  `Bootstrap/ToolInstaller`, `Bootstrap/BootstrapCoordinator`.
- §3.1.5 New `Diagnostics/` module — `LogExporter`, `Redactor`,
  `DiagnosticBundle`.
- §3.1.6 Split `Job` (in-flight) from `HistoryEntry` (persisted). History
  → SQLite (`history.db`). Audit §3.3.1.
- §3.1.7 New `Secrets/` module — backs ADR-0011.
- §3.1.9 New `Plugins/` module — backs ADR-0013.

## Phase 12 — mpm + chezmoi feature gap (v1.x)

Audit §2.1, §2.2. Wire features mpm and chezmoi already expose but
Sojourn doesn't surface:

- §2.1.1 Wire `mpm sbom --cyclonedx` into every push. Commit
  `sbom.cyclonedx.json` alongside `packages.toml`. Cross-reference with
  OSV.
- §2.1.2 PURL specifiers (`pkg:npm/left-pad`) in `packages.toml`
  per-machine override schema.
- §2.1.3 `mpm sync` (registry metadata refresh) wired into daily
  background activity.
- §2.2.1 `.chezmoiexternal.toml` first-class UX. See
  [reference/externals.md](../reference/externals.md). Pane: §4.1.1.
- §2.2.3 Replace `apply --force` post-diff with `chezmoi merge` for text
  dotfiles. Keep `--force` only for non-mergeable types.
- §2.2.5 `chezmoi unmanaged` cross-referenced with `dotfile_owners.toml`
  → "Unmanaged" tab. Pane: §4.1.3.
- §2.2.6 `chezmoi forget` per-file action. Pane: §4.1.4.
- §2.2.7 Embed `chezmoi doctor` in diagnostics export bundle.
- §2.2.8 `chezmoi state` controls (force-rerun, skip-rerun). Pane:
  §4.1.5.
- §2.2.14 `chezmoi update` wrap (refreshes externals).

## Phase 13 — Native backends + extra config (v1.x; closes ADR-0010)

Audit §2.3, §2.4. Build the native backends + capture extra config
surfaces:

- §2.3 Native `BrewService`, `CaskService`, `MasService` per
  [decisions/0010-native-brew-keep-mpm.md](../decisions/0010-native-brew-keep-mpm.md).
- §2.4.1 Brew taps capture + UI subsection.
- §2.4.2 Brew services capture + UI subsection (running/loaded/stopped).
- §2.4.3 LaunchAgents promoted from cleanup orphan to first-class
  managed surface (review tier).
- §2.4.4 macOS Login Items via `SMAppService` (macOS 13+).
- §2.4.8 Tool version managers (mise, asdf, rustup, sdkman, volta) as
  dotfile-classified.

## Phase 14 — Plugin host + secret broker (v1.x; promotes ADR-0011 + ADR-0013)

Audit §2.6, §2.7. Build the extension surface + secret-broker abstraction:

- §2.6 Secret broker abstraction per ADR-0011. Detection ladder
  (1Password → Bitwarden → Keychain → age → plaintext refused).
  "Insert secret reference" wizard. Common configs (`.aws/credentials`,
  `.npmrc`, etc.) become `op://` references by default.
- §2.7 Plugin protocol per
  [reference/plugin-protocol.md](../reference/plugin-protocol.md). JSON-RPC
  over stdio. cosign signature verification. Reference plugins: mise,
  gh extension, krew/helm-plugin.
- §3.4 Plugin host module (already created in Phase 11).
- §4.1.11 Plugins pane in UI.

Promotes [decisions/0011-secret-broker-abstraction.md](../decisions/0011-secret-broker-abstraction.md)
and [decisions/0013-out-of-process-plugins.md](../decisions/0013-out-of-process-plugins.md)
to Accepted.

---

## Verification per phase

1. `swift test` passes.
2. `xcodegen generate && xcodebuild test -scheme Sojourn -destination 'platform=macOS'`
   passes (post-Phase-0).
3. `gitleaks dir --config=.gitleaks.toml` passes.
4. `git commit -s` + `git push origin main`.

## Out of scope

| Item | Tracked in |
|---|---|
| Sandboxed-app prefs (FDA-gated) | [process/future.md](../process/future.md) |
| Concurrent-write merge (three-way) | [decisions/0012-cooperative-writer-lock.md](../decisions/0012-cooperative-writer-lock.md) — v1 ships cooperative lock |
| SwiftTerm-embedded console pane | [process/future.md](../process/future.md) |
| `SMAppService.agent` (background-only LaunchAgent) | [process/future.md](../process/future.md) |
| Mac App Store distribution | sandbox conflicts with subprocess invocation |
| Non-macOS platforms | [decisions/0014-no-linux-no-helling-plugin.md](../decisions/0014-no-linux-no-helling-plugin.md) |
| Hosted backend | local-only by design |
| Discover pane (cfprefsd watcher) | [process/open-questions.md](open-questions.md) §4 — maintainer decision |

## Open questions

Decisions deferred to the maintainer block phases 12–14 progress. Tracked
in [process/open-questions.md](open-questions.md).
