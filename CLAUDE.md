# CLAUDE.md — guidance for Claude Code working on Sojourn

Sojourn is a macOS 14+ SwiftUI app that unifies package management, dotfile sync,
and app-preference sync across Macs. It is a GUI layer over `mpm`, `chezmoi`,
`git`, `defaults`, and bundled `gitleaks` + `age`. It is GPL-3.0-or-later.

## Architecture invariants (do not violate)

1. **Never link GPL-2.0-only dependencies.** `mpm` is GPL-2.0-only. Sojourn invokes
   it only as a subprocess, via argv + JSON/TOML output + exit code. Same for
   `chezmoi`, `git`, and `defaults`. No FFI. No embedding. No shared libraries.
2. **UI never calls `Process` directly.** UI reads `AppStore`; UI dispatches
   intents to `JobRunner`; `JobRunner` calls `Service` actors; `Service` actors
   own the subprocess boundary. A PR that calls `Process(...).run()` from a
   SwiftUI view will be rejected.
3. **Every subprocess invocation is a `Job`.** Jobs have id, start/end time,
   termination status, and a line-buffered log. Jobs are cancellable.
4. **Services are actors.** One actor per external CLI. No shared mutable state
   outside actors. Use `AsyncStream` / `AsyncThrowingStream` for streaming
   output.
5. **Destructive operations snapshot first.** Before any `chezmoi apply`,
   `defaults import`, `mpm restore`, or `git pull --force`, write a pre-op
   snapshot to `~/Library/Application Support/Sojourn/backups/`. 30-day
   retention.
6. **Explicit push/pull; one active writer.** No continuous bidirectional sync.
   The `.sojourn/active.toml` lock is cooperative, not authoritative — git
   doesn't enforce locking. A pull must resolve any conflicts before push is
   allowed.
7. **No auto-install with lifecycle scripts without user consent.** Even inside
   cooldown. Covers `npm preinstall/postinstall`, `pip` build hooks,
   `cargo build.rs`, Homebrew cask installers.
8. **Paths are probed, not `which`-ed.** App-context `PATH` is LaunchServices-
   minimal. Use `ToolLocator` with hardcoded candidates (`/opt/homebrew/bin`,
   `/usr/local/bin`, `~/.cargo/bin`, `~/.local/bin`, `~/go/bin`, `/usr/bin`).
9. **mpm 6.x uses `--table-format json`, NOT `--output-format json`.** The flag
   was renamed between 5.21 and 6.0. Pin to 6.x.
10. **gitleaks runs before every auto-commit.** Findings produce a modal. The
    user can't bypass high-confidence provider-key findings (AWS, GitHub PAT,
    OpenAI, Stripe) for 5 seconds — force them to read.

## Do not do

- Do not add TCA (`swift-composable-architecture`). Raw `@Observable` is the
  project standard.
- Do not add `SwiftGit2`, `SwiftGitX`, `ObjectiveGit`, or link libgit2. Shell
  out to `/usr/bin/git`.
- Do not add `SwiftShell` or `ShellOut` (unmaintained). Use `swift-subprocess`
  or raw `Process + Pipe + AsyncStream`.
- Do not bundle `brew`, `mpm`, or `chezmoi` inside the app. Detect/install the
  user's copy via `BootstrapService`.
- Do not call `/bin/bash -c "..."` unless you specifically need shell features.
  Default to argv invocation of the explicit binary path.
- Do not symlink anything in `~/Library/Preferences`, `~/Library/Containers`,
  or `~/Library/Application Support` for sync. That model is dead. Use
  `defaults export` / `defaults import`.
- Do not trust APFS `atime` as "last used." Default mount is non-strict atime.
- Do not auto-delete orphans. Always move to Trash (`NSFileManager.trashItem`)
  and log the action.
- Do not embed a GitHub `client_secret` in the app. Device Flow needs only
  `client_id`.
- Do not assume Homebrew installs without `sudo`. `NONINTERACTIVE=1` skips the
  Y/N prompt but still calls `sudo`. Use the signed `.pkg` installer instead.
- Do not write snapshot tests that hash exact subprocess stdout. `mpm` changed
  JSON indentation and key sorting between 5.x and 6.x; `brew` output flaps
  per bug #20976.
- Do not use `NSTask`. It's the Obj-C name for `Process`; use `Process`.
- Do not use `@State` to hold the root `AppStore`. Create it at `App` level,
  inject via `.environment`, read via `@Environment(AppStore.self)`.

## Coding style

- Swift 6.1+. Strict concurrency enabled.
- Everything that can be `Sendable`, is.
- Actors for any isolated state; `@MainActor` for UI-touching types.
- `async/await` over completion handlers. `AsyncStream` / `AsyncThrowingStream`
  for streaming.
- Prefer value types (`struct`, `enum`) for models. Use `@Observable` final
  class only at the store level.
- Errors are typed `enum Error: Swift.Error` per service. Surface causes.
- No force-unwraps in non-test code. No `try!`. No `fatalError` outside
  obviously-unreachable code paths.
- File names match primary declaration. One top-level type per file unless
  trivially related.
- Imports ordered: Foundation → SwiftUI → third-party → first-party.
- Two-space indentation. Prefer trailing closures. Omit `return` in one-liners.
- Use `// MARK: -` to organize long files.

## Test requirements

- Every `Service` actor has unit tests with fixtures under
  `SojournTests/Fixtures/` — checked-in golden files of real mpm, chezmoi, git
  output. Update the fixtures, don't generate them on the fly.
- Integration tests mock `SubprocessRunner` with fixture-backed responses.
  Do not invoke real brew/mpm/chezmoi in tests.
- `SyncCoordinator` push/pull flows have end-to-end tests using a local bare
  git repo as the "remote."
- PR requires: `swift test` passes, `xcodebuild test` passes for
  Sojourn + SojournTests + SojournUITests, `gitleaks dir` passes.
- No network calls in tests. Services must be injectable with mock transports.
- Use Swift Testing (`import Testing`, `@Test`) for new tests. XCTest existing
  tests stay as-is.
- Snapshot tests render UI with a stable `AppStore` seed. Do not compare raw
  screenshots; compare logical accessibility snapshots.

## How to add support for a new package manager

mpm already covers the reliable set (brew, cask, mas, pip, pipx, npm, cargo,
gem, composer, yarn, vscode, uvx). To add one that mpm does not support (e.g.,
`pnpm`):

1. Add a `PackageManager` case in `Models/PackageManager.swift` with id, name,
   CLI binary name, typical install path candidates.
2. Add detection logic in `ToolLocator` with hardcoded candidate paths.
3. If the manager is supported by mpm: add it to the list of managers
   `MPMService` fans out to. No new code.
4. If the manager is NOT supported by mpm: create `PnpmService` actor
   parallel to `MPMService`. Implement the minimum surface: `installed()`,
   `outdated()`, `install(pkgs:)`, `remove(pkgs:)`, `upgrade(pkgs:)`. Return
   the same `ManagerSnapshot` shape.
5. Wire into `PackageStore` aggregation so UI sees uniform results.
6. Add a classification to the auto-update tier table in `Settings.swift`
   (default: "User prompt" if unknown risk profile).
7. Add golden fixtures under `SojournTests/Fixtures/<manager>-*.json`.
8. Update `data/applications/README.md` with the new manager's signature files
   (lockfiles, config paths) so orphan detection can factor it in.
9. Add to `BootstrapService` as an on-demand install option (don't install
   upfront).
10. Document in `docs/SUPPORTED_MANAGERS.md`.

Do not add a new manager without steps 6, 7, and 9.

## Releasing

Tags `v*` trigger `notarize.yml`. The workflow:
1. Builds Sojourn.app with Xcode.
2. Re-signs bundled `gitleaks` and `age` with `--options=runtime`.
3. Codesigns Sojourn.app with Developer ID Application.
4. Creates DMG via `create-dmg`.
5. Submits to Apple notary service, staples.
6. Publishes GitHub release with DMG attached.
7. Publishes Homebrew cask tap update.

Never ship a release where `spctl --assess --verbose=4 Sojourn.app` fails on
a clean Sequoia/Tahoe VM.

## When in doubt

- Prefer boring, documented Apple APIs over third-party packages.
- Prefer small Swift files over large ones.
- Prefer explicit passes over side effects.
- Prefer "ship a feature 80% as well as envisioned" over "don't ship."
- Ask the project owner (see `MAINTAINERS.md`) before adding a dependency.
