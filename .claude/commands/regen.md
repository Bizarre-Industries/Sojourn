---
description: Regenerate Sojourn.xcodeproj from project.yml via xcodegen + verify clean build.
---

Regenerate `Sojourn.xcodeproj` from `project.yml` via xcodegen and
verify the build still works.

Steps:

1. Confirm `xcodegen` is available: `command -v xcodegen` (install
   via `brew install xcodegen` if missing).
2. Run `xcodegen generate` from the repo root. Report any warnings.
3. If `project.yml` was modified in the working tree, stage
   `Sojourn.xcodeproj/project.pbxproj` alongside the yml change in
   the next commit (the pbxproj is the regenerated artifact and
   must move atomically with its source).
4. Run `swift build` to confirm SPM resolution still works.
5. Optional sanity check: `xcodebuild -scheme Sojourn -destination
   'platform=macOS,arch=arm64' -showBuildSettings | head -30` to
   confirm `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` reflect
   the latest project.yml values.

When to run:
- After adding or removing source files (xcodegen scans `sources:`
  paths and pulls them into the project).
- After modifying any target's settings (build configuration,
  signing, dependencies, scripts).
- After bumping `CURRENT_PROJECT_VERSION` or `MARKETING_VERSION`.
- After modifying `Package.swift` SPM dependencies (xcodegen
  re-resolves the package graph).

If the build breaks after regen, surface the diff in
`Sojourn.xcodeproj/project.pbxproj` to identify what xcodegen
changed.
