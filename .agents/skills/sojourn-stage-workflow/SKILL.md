---
name: sojourn-stage-workflow
description: 'Codifies the v0.X release-stage loop: bump build → ADRs (if needed) → council/self-critique → service code → pane code → tests → smoke check → gitleaks → CHANGELOG → commit → next stage. Trigger when starting any new stage of the active v0.X plan, when the user says "next stage" / "proceed to stage N" / "start stage N", or when scanning docs/process/plans/v0.X-plan.md for execution-order steps.'
---

# Sojourn stage workflow

This skill formalizes the repeated 8-stage loop that Sojourn follows
through every minor-version release (v0.2, v0.3, v0.4 ...). Each
stage is a separate commit on `main`. Build numbers increment per
stage. Tag and ship only after the final stage's acceptance criteria
pass.

## Per-stage steps (canonical order)

1. **Pick the stage.** Read `docs/process/plans/v0.X-plan.md`
   "Execution order" section. The first stage with no commit
   matching `vX.Y stage N: ...` is yours. Mark it `[in_progress]`
   in TodoWrite.

2. **Bump build.** Edit `project.yml`:
   `CURRENT_PROJECT_VERSION: N` → `N+1`. (`MARKETING_VERSION`
   stays at the target version until tag time.)

3. **Determine council trigger.** Per `AGENTS.md` / `CLAUDE.md`
   "Council (the only
   gate)" list:
   - new ADR creation
   - new external dependency (Brewfile / Package.swift / GH Actions / MCP)
   - breaking change to a `Service` actor's public API or persisted
     schema
   - code deletion >100 LOC in one commit
   - any change under `Sojourn/Secrets/`, `Sojourn/Policy/`, signing
     config, or `notarize.yml`

   If yes → council fires (use `/council` skill or spawn 5
   `council-*` subagents in parallel + write deliberation log).
   If no → spawn `self-critique` subagent on the diff before commit.

4. **Write the source code.** Apply per-stage spec from the plan:
   - Service file under `Sojourn/Services/` (actor pattern; injects
     `SubprocessRunner`, `ToolLocator`).
   - Pane file under `Sojourn/UI/Panes/` (PaneScaffold + PaneHero).
   - AppStore wiring (immutable `let` member + observable `var`
     snapshot + `refreshX()` method).
   - Pane enum extension if the change adds a sidebar entry.

5. **Write the tests.** Under `SojournTests/Services/<Name>Tests.swift`
   using Swift Testing (`@Test`, `#expect`, `#require`). Fixture
   files under `SojournTests/Fixtures/<topic>/<name>.txt`.
   Subprocess invocation tested via parser-only unit tests; full
   subprocess flow runs once locally as smoke (per `AGENTS.md` / `CLAUDE.md`
   "smoke-run before claiming done").

6. **Smoke check.** Per agent-guide verification rule: any code that
   crosses a process or network boundary gets one real invocation
   against the real binary before claiming the stage done.
   Compilation is not correctness.

7. **Gitleaks.** Run `gitleaks dir . --no-banner`. If a leak shows,
   fix or allowlist (synthetic placeholders go in
   `.gitleaks.toml::[allowlist].regexes`).

8. **Build clean.** `swift build` zero warnings. If the stage
   touched the Xcode target, also `xcodegen generate` then
   `xcodebuild -scheme Sojourn -destination 'platform=macOS,arch=arm64' build`.

9. **Run tests.** `xcodebuild test -scheme Sojourn -destination
   'platform=macOS,arch=arm64' -only-testing:SojournTests`. Must
   pass.

10. **Update `CHANGELOG.md`.** Open `[0.X.0] — unreleased` `### Added`
    section. One bullet per file group.

11. **Commit.** Stage explicit files (never `git add -A`). Use
    HEREDOC commit message:
    ```
    vX.Y stage N: <one-line summary>

    - <bullet>
    - <bullet>
    ```
    `git commit -s`. Never `--no-verify`. No agent co-author trailer.

12. **Mark complete.** Update TodoWrite. Move to next stage.

## Stage 8 (release) extra steps

The final stage in every plan is the release. Before tagging:

- Update `Casks/sojourn.rb` `version` + `sha256` (sha comes after
  notarize-and-DMG step in CI).
- Verify `appcast.xml` references the new full DMG (Sparkle delta
  generated in CI from the prior release).
- Update `Sojourn/Info.plist` if needed (CFBundle keys come from
  `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`
  substitution — usually no edit required).
- Run `brew audit --cask --new --online ./Casks/sojourn.rb`.
- Verify `spctl --assess --verbose=4` on built `Sojourn.app` and
  embedded `MasHelper` binary.
- Tag `vX.Y.Z` from `main`; push. `notarize.yml` ships end-to-end.
- After tag push, `replan-on-tag.sh` writes the next plan
  `docs/process/plans/v0.X+1-plan.md` automatically.

## Anti-patterns to avoid

- **Don't skip the smoke check** because tests pass. Agent guide
  "Compilation passing ≠ correctness" — tests verify your
  assumption, not the API.
- **Don't batch multiple stages** into one commit. Each stage's
  changes must be independently reviewable + revertable.
- **Don't forget the council log.** Council fires → log writes →
  THEN commit. Never the other way around.
- **Don't `git add -A`.** Sojourn ships bundled binaries +
  generated artifacts; explicit-list-only protects against
  accidentally committing `.build/`, derived data, or temp files.
- **Don't skip CHANGELOG updates.** The `[Unreleased]` section is
  the running record of what shipped per stage; release note
  generation reads from it directly.

## When NOT to use this skill

- One-off fixes that don't fit the stage model (typo fixes,
  documentation-only changes).
- Hot-fix patches to a previously-released version (use a
  `vX.Y.Z+1` patch flow, not the stage loop).
- Cosmetic refactors that don't advance the active plan.

For those: skip directly to gitleaks + self-critique + commit.
