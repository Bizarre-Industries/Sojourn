# Contributing to Sojourn

Thanks for the interest. Sojourn is GPL-3.0-or-later and actively accepts contributions. Read this end-to-end before opening a PR.

## Before you start

1. Read [CLAUDE.md](CLAUDE.md) — the invariants and "do not do" list apply to humans too.
2. Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — especially §11 (module layout) and §13 (licensing). If your change conflicts with a listed invariant, open an issue for discussion first.
3. Make sure your `git` user info matches the commit you plan to sign: `git config user.email` and `git config user.name`. Sojourn requires Developer Certificate of Origin sign-offs (`git commit -s`).

## Development setup

- macOS 14 Sonoma or later.
- Xcode 16+ (Swift 6.1+ toolchain).
- Homebrew with `gitleaks` (`brew install gitleaks`).
- `chezmoi` and `mpm` on `PATH` if you'll touch the service layer.

```sh
git clone https://github.com/bizarreindustries/sojourn.git
cd sojourn
swift package resolve          # pulls swift-subprocess + MenuBarExtraAccess
# Open Sojourn.xcodeproj in Xcode for app builds
```

## What goes in a PR

### Required

- [ ] Branch is rebased on `main`; no merge commits.
- [ ] All commits are signed off with `git commit -s`.
- [ ] `swift test` passes locally.
- [ ] `xcodebuild test -scheme Sojourn` passes locally (once the Xcode project is committed).
- [ ] `gitleaks dir --no-git` passes (no secrets).
- [ ] New service methods have fixture-backed unit tests under `SojournTests/Fixtures/`.
- [ ] Public types have a one-line `///` doc comment citing the design-doc section they implement.
- [ ] No new third-party dependency without explicit maintainer approval in the PR.

### Style

- Swift 6.1 strict concurrency; everything that can be `Sendable`, is.
- Two-space indentation.
- Imports: Foundation → SwiftUI → third-party → first-party.
- One top-level type per file. File name matches primary declaration.
- Comments explain **why**, not **what**.
- No `TODO` / `FIXME` — surface incomplete work in the PR description instead.

### Commit message format

Imperative, lowercase, scoped when it helps. Examples:

```
svc(mpm): surface per-manager errors in installed()
ui: wire PackagesPane to ManagerSnapshot
docs: expand §8 TCC canary rationale
```

No `Co-authored-by` trailers. No `Generated with Claude` trailers. Sign-off trailer is mandatory.

## PR review process

1. Open the PR against `main`.
2. CI runs: `swift test`, `xcodebuild test`, `gitleaks`, CodeQL.
3. A maintainer (see `MAINTAINERS.md` when it exists) reviews for architecture alignment with `docs/ARCHITECTURE.md` and invariants in `CLAUDE.md`.
4. Squash-merge is default. Use merge-commit only when preserving a bisectable sequence matters.

## Things that will get your PR rejected fast

- Adding TCA, SwiftGit2, libgit2, SwiftShell, or any library that embeds a GPL-2.0-only tool.
- Linking `mpm` or `chezmoi` as a library (breaks the IPC-not-linking invariant).
- Calling `Process` directly from a `View`.
- `@State` holding the root `AppStore`.
- Silent `catch` blocks or retry loops added "defensively."
- Snapshot tests that hash exact subprocess stdout.
- Symlinking anything in `~/Library/Preferences`.

## Bug reports

Open an issue with: macOS version, Xcode version, Sojourn version, reproduction steps, and the relevant excerpt from the in-app Log Console (Settings -> Logs -> Export).

## Security

See [docs/SECURITY.md](docs/SECURITY.md) for the threat model. Report security-sensitive issues privately to the maintainer email in `SECURITY.md`, not in a public issue.

## License

By contributing, you agree your contribution is licensed under GPL-3.0-or-later and you have the right to submit it under the Developer Certificate of Origin (see `git commit -s`).
