# AGENTS.md — entry point for any AI agent editing Sojourn

This file is the agent-agnostic source. `CLAUDE.md` is kept as the
Claude Code mirror because Claude loads that name natively. Keep both
files semantically in sync before committing agent workflow changes.
Read top to bottom before touching code.

## What Sojourn is

A native macOS 26+ SwiftUI app. Brew-native Mac config manager. Brewfile +
chezmoi as the declarative source of truth. Generations panel for
rollback, macOS Features panel for system tweaks (Touch ID for sudo,
dock layout, Finder defaults). What nix-darwin would be if it didn't
make you learn Nix. GPL-3.0-or-later. Personal/homelab use.

## How you operate

You are an autonomous agent. Read the active plan at
`docs/process/plans/v0.X-plan.md` (X = highest version present). Execute
top-to-bottom. Do not pause for confirmation on routine work.

You may pause only on:

- A council deliberation has been requested by the trigger list (below)
  and the verdict has not yet been written to the matching
  `.claude/council-logs/` or `.codex/council-logs/` directory. Wait for
  the file, then read it before acting.
- The plan's premise has been invalidated by something you discovered
  (an upstream tool was archived, an Apple API was removed, a CVE
  changed the threat model). Update the plan in place, commit the
  update, then proceed.

You may **not** pause on:

- "Should I rename this variable?" — decide.
- "Is this the right test?" — write the test you'd defend.
- "Will the user prefer X or Y aesthetics?" — pick X, document why,
  move on. Aesthetic choices are reversible.

If you are uncertain about a third-party tool's current behavior, flag
set, version, or availability: **search and verify**, do not guess. LLM
training data drifts. Compilation passing is not correctness. After
writing code that calls an external API, framework, or system service,
run a minimal smoke check before moving on.

## Council (the only gate)

Council automatically fires before you commit a change that does any of:

- Creates a new ADR.
- Adds a new external dependency (Brewfile entry, `Package.swift`,
  GitHub Actions workflow, MCP server).
- Makes a breaking change to a `Service` actor's public API or a
  persisted-on-disk schema (Brewfile format, generations tarball
  schema, `cooldowns.toml`, `prefs.toml`, `machines.toml`).
- Deletes more than 100 lines of code in a single commit.
- Touches `Sojourn/Secrets/`, `Sojourn/Policy/`, signing configuration,
  or `notarize.yml`.

Council members are five mirrored subagents: Claude Code reads
`.claude/agents/council-*.md`; Codex reads `.codex/agents/council-*.toml`.
Roles are `architect`, `security`, `devil-advocate`, `ux-critic`,
`perf-skeptic`. They fire in parallel single-shot, return structured
`Decision / Dissents / Risks`. You write a deliberation log to the
matching `.claude/council-logs/<YYYY-MM-DD>-<slug>.md` or
`.codex/council-logs/<YYYY-MM-DD>-<slug>.md` before continuing.

Everything else: spawn one `self-critique` subagent on the diff before
commit. Cheaper, catches obvious mistakes, doesn't need formal logging.

## Architecture invariants (do not violate)

1. **No GPL-2.0-only deps linked.** chezmoi, git, age, gitleaks are
   invoked as subprocess only — argv + JSON/TOML output + exit code.
   No FFI. No embedding. No shared libraries. ADR-0001 (amended for
   v0.2 — narrowed scope post-mpm-drop).
2. **UI never calls `Process` directly.** UI reads `AppStore`; UI
   dispatches intents to `JobRunner`; `JobRunner` calls `Service`
   actors; `Service` actors own the subprocess boundary. A view that
   calls `Process(...).run()` will be rejected.
3. **Every subprocess invocation is a `Job`.** Jobs have id,
   start/end time, termination status, line-buffered log. Jobs are
   cancellable.
4. **Services are actors.** One actor per external CLI. No shared
   mutable state outside actors. `AsyncStream` /
   `AsyncThrowingStream` for streaming output.
5. **Destructive operations snapshot first.** Before any
   `chezmoi apply`, `defaults import`, `brew bundle install --cleanup`,
   or `git pull --force`, write a pre-op snapshot to
   `~/Library/Application Support/Sojourn/generations/`. 30-day
   retention.
6. **Explicit push/pull; one active writer.** No continuous
   bidirectional sync. The `.sojourn/active.toml` lock is cooperative,
   not authoritative — git doesn't enforce locking. A pull resolves any
   conflict before push is allowed. ADR-0012.
7. **No auto-install with lifecycle scripts without user consent.**
   Even inside cooldown. Covers `npm preinstall/postinstall`, `pip`
   build hooks, `cargo build.rs`, Homebrew cask installers.
8. **Paths are probed, not `which`-ed.** App-context `PATH` is
   LaunchServices-minimal. Use `ToolLocator` with hardcoded candidates
   (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.cargo/bin`,
   `~/.local/bin`, `~/go/bin`, `/usr/bin`).
9. **gitleaks runs before every auto-commit.** High-confidence
   provider-key findings (AWS, GitHub PAT, OpenAI, Stripe) cannot be
   bypassed for 5 seconds.
10. **macOS 26.0 (Tahoe) is the floor.** Don't gate on lower versions
    "for compatibility." Don't add `if #available(macOS 14, *)` checks.
    Personal tool, locked decision.
11. **Single backend: brew bundle.** No mpm, no Nix, no `Backend`
    protocol. ADR-0018 supersedes 0010. ADR-0022-rejected captures
    why not Nix.

## Do not do

- Add TCA (`swift-composable-architecture`). Raw `@Observable` is the
  standard.
- Add `SwiftGit2`, `SwiftGitX`, `ObjectiveGit`, or libgit2. Shell out
  to `/usr/bin/git`. ADR-0007.
- Add `SwiftShell` or `ShellOut`. Use `swift-subprocess` or raw
  `Process + Pipe + AsyncStream`.
- Bundle `brew` or `chezmoi` inside the app. Detect/install via
  `BootstrapService`.
- Symlink anything in `~/Library/Preferences`,
  `~/Library/Containers`, or `~/Library/Application Support` for sync.
  ADR-0002. Use `defaults export`/`defaults import`.
- Trust APFS `atime` as "last used." Default mount is non-strict
  atime.
- Auto-delete orphans. Always `NSFileManager.trashItem` and log.
- Embed a GitHub `client_secret`. Device Flow needs only `client_id`.
- Assume Homebrew installs without `sudo`. `NONINTERACTIVE=1` only
  skips the Y/N prompt — it still calls `sudo`. Use the signed `.pkg`
  installer per ADR-0008.
- Hash exact subprocess stdout in snapshot tests. `brew` output flaps
  per [bug #20976](https://github.com/Homebrew/brew/issues/20976).
- Use `NSTask`. Obj-C alias for `Process`; use `Process`.
- Hold the root `AppStore` in `@State`. Create at `App` level, inject
  via `.environment`, read via `@Environment(AppStore.self)`.
- Re-introduce the `Backend` protocol "just in case Nix comes back."
  YAGNI.
- Keep the v0.3 redirect window for deleted UPPERCASE doc files.
  `git log` is the redirect.

## Coding style

- Swift 6.1+. Strict concurrency.
- Everything that can be `Sendable`, is.
- Actors for any isolated state; `@MainActor` for UI.
- `async/await` over completion handlers.
- Prefer value types. `@Observable` final class only at the store
  level.
- Errors are typed `enum Error: Swift.Error` per service. Surface
  causes.
- No force-unwraps in non-test code. No `try!`. No `fatalError`
  outside obviously-unreachable paths.
- File names match primary declaration. One top-level type per file.
  After v0.2 split, no UI file over 400 lines.
- Imports ordered: Foundation → SwiftUI → third-party → first-party.
- Two-space indentation. Trailing closures. Omit `return` in
  one-liners.
- `// MARK: -` to organize long files.
- macOS 26 APIs called directly. No version-availability gates below 26.

## Test requirements

- Every `Service` actor has unit tests with fixtures under
  `SojournTests/Fixtures/` — checked-in golden files of real
  brew/chezmoi/git output. Update fixtures, don't generate on the fly.
- Integration tests mock `SubprocessRunner` with fixture-backed
  responses. Do not invoke real brew/chezmoi/mas in tests.
- `SyncCoordinator` push/pull flows: end-to-end tests using a local
  bare git repo as the "remote."
- PR requires: `swift test` passes, `xcodebuild test` passes for
  Sojourn + SojournTests + SojournUITests, `gitleaks dir` passes.
- No network calls in tests. Services injectable with mock transports.
- Use Swift Testing (`import Testing`, `@Test`) for new tests. XCTest
  legacy stays.
- Snapshot tests use stable `AppStore` seed. Compare logical
  accessibility snapshots, not raw screenshots.
- After writing code that calls an external API: smoke-run it once
  before claiming done. Compilation ≠ correctness.

## Project structure (canonical)

- `Sojourn/App/` — entry point + `AppStore`.
- `Sojourn/Bootstrap/` — `BootstrapCoordinator`, `ToolInstaller`,
  `ToolLocator`, `ToolProbe`.
- `Sojourn/Services/` — actors. One per external CLI:
  `BrewBundleService`, `ChezmoiService`, `GitService`,
  `MacOSFeaturesService`, `GenerationService`, `PrefService`,
  `MasService`, `SparkleService`, `JobRunner`.
- `Sojourn/UI/` — views.
  - `Sojourn/UI/MainWindowView.swift` — `NavigationSplitView` host.
  - `Sojourn/UI/Panes/<Name>Pane.swift` — one per pane.
- `Sojourn/Models/` — value types only.
- `Sojourn/Persistence/` — `cooldowns.toml`, `prefs.toml`,
  `machines.toml` IO; generations tarball schema.
- `Sojourn/Policy/` — `AdvisoryService` (brew vulns shell-out).
- `Sojourn/Secrets/` — age/keychain glue. **Council fires on every
  change here.**
- `Sojourn/Resources/` — bundled binaries (age, gitleaks),
  `preference-domains.json`.
- `docs/` — strict Diátaxis. `decisions/` (ADRs), `process/`,
  `design/` are siblings.
  - `docs/process/plans/v0.X-plan.md` — current execution target.
- `.claude/` — Claude Code config.
  - `.claude/agents/council-*.md` — 5 council members.
  - `.claude/agents/mechanical.md` — Haiku-backed for rename/move/format.
  - `.claude/hooks/` — `replan-on-tag.sh`, `mark-replanned.sh`,
    `never-guess.sh`, `pre-commit-gitleaks.sh`.
  - `.claude/council-logs/` — deliberation transcripts.
  - `.claude/.last-shipped-tag` — replan-on-tag marker (ignored from git).
- `.codex/` — Codex config.
  - `.codex/agents/*.toml` — Codex mirrors of the Claude subagents.
  - `.codex/hooks.json` + `.codex/hooks/` — Codex lifecycle hooks.
  - `.codex/council-logs/` — Codex deliberation transcripts.
  - `.codex/.last-shipped-tag` — replan-on-tag marker (ignored from git).
- `.agents/skills/` — Codex project skills. Mirrors `.claude/skills/`.

## Skills (`.agents/skills/` and `.claude/skills/`)

Project-local skills are loaded automatically. Invoke them via the
Skill tool when a task matches the trigger; do not paraphrase what
they teach. Codex reads `.agents/skills`; Claude Code reads
`.claude/skills`. Keep the two trees mirrored. Roster:

- **`swift-concurrency`** — actor isolation, Sendable, @MainActor,
  data race fixes, async/await migration. Trigger: any change inside
  `Sojourn/Services/` or `Sojourn/Store/`, any concurrency-related
  warning, any new actor type.
- **`swift-testing-expert`** — `#expect` / `#require` macros, traits,
  parameterized tests, async waiting. Trigger: any new test in
  `SojournTests/`, any flaky test investigation, any XCTest →
  Swift Testing migration.
- **`swiftui-expert-skill`** — view composition, state management,
  macOS 26 Liquid Glass, performance traces. Trigger: any change
  inside `Sojourn/UI/`, any pane file edit, any Instruments `.trace`
  reference.
- **`xcode-build-orchestrator`** — end-to-end build optimization
  (compilation, project settings, packages). Trigger: build > 30s
  locally, any `xcodegen` regeneration that surfaces new warnings,
  any "make Xcode faster" ask.
- **`core-data-expert`** — only relevant if Sojourn ever moves
  persistence off TOML/SQLite to Core Data. v0.3 doesn't use it.
- **`auto-skill` / `skill-discovery`** — observe + suggest community
  skills matching repeated patterns. Reactive, not load-bearing.
- **`sojourn-stage-workflow`** — codifies the v0.X 8-stage release
  loop (bump build → ADRs → council → service → pane → tests →
  gitleaks → commit → next stage). Invoke at the start of every
  stage to skip re-deriving the loop from this file.

When a skill applies, invoke it via the Skill tool BEFORE writing
code. Skipping the skill and re-deriving its content burns tokens
and produces inconsistent output across sessions.

## Slash commands and app commands

Claude Code project-local commands live in `.claude/commands/`.
Codex command mirrors live in `.codex/commands/` and are backed by
native tools, hooks, and subagents. Keep both command sets aligned.
The Codex-to-Claude MCP bridge in `.codex/config.toml` is disabled by
default. Enable it only for a deliberate local bridge session, restart
Codex, and do not commit `enabled = true`; peer agents must not invoke
peer MCP/council flows recursively.
Current shortcuts:

- **`/council`** — fire the 5-member council on the current diff.
  Equivalent to dispatching all 5 council-* subagents in parallel,
  collecting verdicts, writing a deliberation log to
  `.claude/council-logs/<date>-<slug>.md` or
  `.codex/council-logs/<date>-<slug>.md`.
- **`/stage-commit`** — pre-flight a stage commit: gitleaks, swift
  build, xcodebuild test, self-critique on diff. Bumps
  `CURRENT_PROJECT_VERSION`. Drafts the commit message.
- **`/regen`** — regenerate `Sojourn.xcodeproj` from `project.yml`
  via xcodegen. Run after adding/removing source files or modifying
  target settings.

## When in doubt

- **Architectural change** → write a new ADR under `docs/decisions/`
  before merging. Council will fire automatically.
- **New doc** → see `docs/process/DOCS_POLICY.md` for quadrant
  placement, naming, stub policy.
- **Adding a package manager** →
  `docs/how-to/development/add-package-manager.md`.
- **Open question / deferred decision** →
  `docs/process/open-questions.md`.
- **Don't know something** → search the upstream source. Don't guess.
- **Code "looks right" but you didn't run it** → it's not done. Run it.

## Releasing

Tags `v*` trigger `notarize.yml`:

1. Build Sojourn.app with Xcode.
2. Re-sign bundled `gitleaks` and `age` with `--options=runtime`.
3. Codesign Sojourn.app with Developer ID Application.
4. Create DMG via `create-dmg`.
5. Submit to Apple notary, staple.
6. Publish GitHub release with DMG attached.
7. Sparkle EdDSA-sign DMG, append to appcast.
8. `brew bump-cask-pr` to publish the cask.

Never ship a release where `spctl --assess --verbose=4 Sojourn.app`
fails on a clean Tahoe VM.

After tag push: `replan-on-tag.sh` writes the next version's plan
file at `docs/process/plans/v0.X-plan.md` and the next session picks
it up automatically. No human intervention required.

## Memory: lessons.md

Every time you fix a class of bug, work around an external tool's
quirk, or learn that an LLM-generated assumption was wrong, append
to `lessons.md`. Format: topic header, date, "Tried / Failed /
Settled-on." This is your future self's reference. The council reads
it before deliberating.
