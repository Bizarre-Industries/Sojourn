// Sojourn — Power surfaces
//
// Each surface exposes a backend that was previously implicit. The Stage 1
// JSX-derived stubs (with hardcoded demo data) are gone in v0.2 — every
// surface now renders a `PaneEmptyState` describing what will populate it
// once the corresponding service is wired in v0.3+. The struct names are
// preserved so future subnav routing can keep its existing `case .x: XPane()`
// references compiling.

import SwiftUI

// MARK: - Job Inspector (routed: .jobs)

struct JobInspectorPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "JOBS · JobRunner · LogBuffer · ANSIParser",
      title: "JOBS.",
      subtitle: "Live tail per Process: PID, runtime, exit code, structured argv. The active-jobs list and per-job log surface in v0.3 once the JobInspectorPane is wired to JobRunner's AsyncStream output."
    )
    .accessibilityIdentifier("pane.jobs")
  }
}

// MARK: - Schedule Inspector

struct ScheduleInspectorPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "SCHEDULE · NSBackgroundActivityScheduler",
      title: "SCHEDULE.",
      subtitle: "Background tasks (refresh-outdated 1h, refresh-advisories 6h) wire here once the scheduler ships in v0.3. The skip-log + next-fire timing render once that's live."
    )
    .accessibilityIdentifier("pane.schedule")
  }
}

// MARK: - age Keys

struct AgeKeysPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "AGE · X25519 · KeychainBroker",
      title: "AGE KEYS.",
      subtitle: "Local identity at ~/.config/chezmoi/key.txt; per-machine recipients in .sojourn/recipients.txt. The list + rotate flow ship in v0.3 alongside the secrets broker."
    )
    .accessibilityIdentifier("pane.age")
  }
}

// MARK: - chezmoi Templates

struct ChezmoiTemplatesPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "TEMPLATES · chezmoi data · managed · diff",
      title: "TEMPLATES.",
      subtitle: "Per-host conditionals + variables surfaced from `chezmoi data --format=json`. Parsed view ships in v0.3."
    )
    .accessibilityIdentifier("pane.chezmoi-templates")
  }
}

// MARK: - gitleaks Rules

struct GitleaksRulesPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "RULES · gitleaks 8.30.1 · MIT · bundled",
      title: "RULES & ALLOWLIST.",
      subtitle: "Builtin pattern list + per-repo allowlist editor. Each rule's hit count + expiry land once we read `.gitleaks.toml` in v0.3."
    )
    .accessibilityIdentifier("pane.gitleaks-rules")
  }
}

// MARK: - Authorization

struct AuthorizationPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "AUTHORIZATION · TCC · SMAppService · Touch ID",
      title: "AUTHORIZATION.",
      subtitle: "FDA grant status, helper-tool registration, Touch ID-for-sudo state. Reads from TCC.db + ServiceManagement once wired in v0.3."
    )
    .accessibilityIdentifier("pane.authorization")
  }
}

// MARK: - Manager Detail

struct ManagerDetailPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "MANAGER DETAIL · per-ecosystem deep-dive",
      title: "MANAGER DETAIL.",
      subtitle: "Drilldown into a single Brewfile entry tier (mas / brews / casks / cargo / etc.) with per-package install + outdated state. Lands in v0.3 alongside the outdated parsing."
    )
    .accessibilityIdentifier("pane.manager-detail")
  }
}

// MARK: - Backups

struct BackupsPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "BACKUPS · ~/Library/Application Support/Sojourn/generations/",
      title: "BACKUPS.",
      subtitle: "Pre-op tarball list with per-snapshot stats. Restore action lands when SnapshotService.rollback() ships in v0.3."
    )
    .accessibilityIdentifier("pane.backups")
  }
}

// MARK: - defaults Discover

struct DefaultsDiscoverPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "DEFAULTS DISCOVER · cfprefsd · plutil",
      title: "DEFAULTS DISCOVER.",
      subtitle: "Live record-mode that watches cfprefsd writes and surfaces which preference key changed when. Lands in v0.3 alongside the Preferences pane."
    )
    .accessibilityIdentifier("pane.defaults-discover")
  }
}

// MARK: - Repo Setup

struct RepoSetupPane: View {
  var body: some View {
    PaneEmptyState(
      eyebrow: "REPO SETUP · git · GitHub Device Flow",
      title: "REPO SETUP.",
      subtitle: "First-run wizard: pick a sync remote, authenticate via GitHub Device Flow, create an empty .sojourn/ scaffold. The interactive wizard ships in v0.3."
    )
    .accessibilityIdentifier("pane.repo-setup")
  }
}
