# Adding a preference domain

## Goal

Add a new app or system component to Sojourn's tracked-preference list
so its plist gets exported / imported by `PrefService`.

## Prereqs

- The app's plist lives at `~/Library/Preferences/<bundle-id>.plist`
  (unsandboxed) or `~/Library/Containers/<bundle-id>/Data/Library/Preferences/<bundle-id>.plist`
  (sandboxed).
- You can read it with `defaults read <bundle-id>` (without errors).
- Familiarity with Sojourn's source tree.

## Steps

1. **Verify the bundle ID**:

   ```sh
   defaults read <bundle-id> | head
   ```

   Should print the plist content. If `defaults` reports
   "domain does not exist", the app hasn't been launched yet.

2. **Add an entry to `data/preference-domains.toml`** in the Sojourn
   source tree:

   ```toml
   [[domain]]
   bundle_id   = "com.sublimetext.4"
   name        = "Sublime Text"
   sandboxed   = false
   tier        = "auto"        # or "prompt" / "review"
   notes       = "Power-user editor; preferences include keymaps + plugins."
   ```

   For sandboxed apps:

   ```toml
   [[domain]]
   bundle_id   = "com.tinyspeck.slackmacgap"
   name        = "Slack"
   sandboxed   = true
   tier        = "prompt"
   notes       = "Slack stores prefs in ~/Library/Containers/. Requires FDA."
   ```

3. **Write the unit test fixture**:

   In `SojournTests/Fixtures/preferences/`, add
   `<bundle-id>.plist.xml` — the canonical export. Generate via:

   ```sh
   defaults export <bundle-id> - | plutil -convert xml1 -o - -
   ```

   Trim user-specific values (paths, hostnames) before checking in.

4. **Add a unit test** in `SojournTests/PrefServiceTests/RoundTripTests.swift`:

   ```swift
   @Test
   func roundTripSublimeText() async throws {
       let fixture = TestFixture("preferences/com.sublimetext.4")
       let svc = PrefService(runner: MockSubprocessRunner(fixture: fixture))
       let exported = try await svc.export(bundleID: "com.sublimetext.4")
       try await svc.import(bundleID: "com.sublimetext.4", from: exported)
       #expect(svc.lastImportExitCode == 0)
   }
   ```

5. **Run tests** locally:

   ```sh
   swift test --filter PrefServiceTests.RoundTripTests
   ```

6. **Open a PR** with:
   - The TOML entry.
   - The fixture.
   - The test.
   - A note in the PR body about whether you tested manually
     (specifically: which Mac, which version of the app, did the
     prefs round-trip survive an app relaunch).

## Verification

- `swift test` passes.
- `gitleaks dir` against the test fixture passes (no real secrets).
- The Preferences pane in a debug-built Sojourn shows the new domain
  as detectable.

## Troubleshooting

- **"Plist contains huge auto-saved state"** — some apps (e.g.
  Xcode) store window-state and recent-files in the plist. These
  flap on every push. Use `prompt` tier and split off the noise via
  exclude rules in `prefs.toml`.
- **"Sandboxed app still grey after FDA"** — verify by
  `defaults read /Library/Preferences/com.apple.TimeMachine.plist`
  works (the canary). If yes, the app's container path may be
  unusual; check `~/Library/Containers/<bundle>/Data/Library/Preferences/`.

## See also

- [reference/pref-domains.md](../../reference/pref-domains.md) —
  full classification matrix.
- [reference/preference-sync.md](../../reference/preference-sync.md)
  — export/import flow.
- [decisions/0002-no-symlink-preferences.md](../../decisions/0002-no-symlink-preferences.md).
- [process/audit-2026-04.md §1.5](../../process/audit-2026-04.md#1-doc-level-inconsistencies)
  — Discover pane (deferred).
