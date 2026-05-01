// Sojourn — Power surfaces (10 panes per chat 2 expansion).
//
// Each surface exposes a backend that was previously implicit. Translations
// of `power.jsx` (Job / Schedule / age / chezmoi templates / gitleaks rules)
// and `power2.jsx` (Authorization / Manager detail / Backups / defaults
// Discover / Repo setup). Stage 1 ships visually-rich stub panes wired into
// the sidebar; Stage 2 (Wave B) binds each to its concrete service actor.

import SwiftUI

// MARK: - Job Inspector

struct JobInspectorPane: View {
  var body: some View {
    PowerScaffold(eyebrow: "POWER / JOBS / JobRunner · LogBuffer · ANSIParser",
                  title: "JOBS.",
                  subtitle: "Live tail per Process. PID, runtime, exit code, structured argv. Cancel chains preserved through Task.cancel().") {
      BzrCallout(
        title: "JobRunner",
        kind: .info,
        bodyText: "@MainActor @Observable. One Task per Job. AsyncStream per stdout/stderr line. 64KB backpressure. Wired to live data in Wave B."
      )
      BzrCard(eyebrow: "RECENT · 5 MOST RECENT") {
        VStack(spacing: 6) {
          jobRow("git push origin main", "exit 0", "1.4s", .ok)
          jobRow("gitleaks dir --staged --no-git", "exit 0", "0.8s", .ok)
          jobRow("brew bundle list --all", "exit 0", "12.3s", .ok)
          jobRow("brew outdated --json", "exit 0", "3.1s", .ok)
          jobRow("chezmoi diff --no-pager --color=false", "running", "0.4s", .lime)
        }
      }
    }
    .accessibilityIdentifier("pane.jobs")
  }

  @ViewBuilder
  private func jobRow(_ cmd: String, _ status: String, _ duration: String, _ kind: StatusDotKind) -> some View {
    HStack(spacing: 10) {
      StatusDot(kind: kind)
      Text(cmd)
        .font(.bzrMono(size: 11))
        .foregroundStyle(Color.txtPrimary)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer()
      Text(duration)
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color.txtTertiary)
      Text(status)
        .font(.bzrMono(size: 10))
        .foregroundStyle(kind == .lime ? Color.bzrLime : Color.txtSecondary)
    }
  }
}

// MARK: - Schedule Inspector

struct ScheduleInspectorPane: View {
  var body: some View {
    PowerScaffold(eyebrow: "POWER / SCHEDULE / NSBackgroundActivityScheduler",
                  title: "SCHEDULE.",
                  subtitle: "Two registered tasks. App Nap-aware. AC-only opt. Skip log retained 30d.") {
      BzrCard(eyebrow: "REFRESH-OUTDATED · 1H · QoS .utility") {
        VStack(alignment: .leading, spacing: 8) {
          HStack { StatusDot(kind: .lime); Text("app.bzr.sojourn.refresh-outdated").font(.bzrMono(size: 11)).foregroundStyle(Color.txtPrimary); Spacer() }
          BzrProgressBar(value: 0.74)
          HStack { Text("NEXT").font(.bzrMono(size: 10)).foregroundStyle(Color.txtTertiary); Spacer(); Text("14m").font(.bzrMono(size: 11)).foregroundStyle(Color.bzrLime) }
        }
      }
      BzrCard(eyebrow: "REFRESH-ADVISORIES · 6H · OSV DELTA") {
        VStack(alignment: .leading, spacing: 8) {
          HStack { StatusDot(kind: .lime); Text("app.bzr.sojourn.refresh-advisories").font(.bzrMono(size: 11)).foregroundStyle(Color.txtPrimary); Spacer() }
          BzrProgressBar(value: 0.32)
          HStack { Text("NEXT").font(.bzrMono(size: 10)).foregroundStyle(Color.txtTertiary); Spacer(); Text("4h 12m").font(.bzrMono(size: 11)).foregroundStyle(Color.bzrLime) }
        }
      }
      BzrCard(eyebrow: "SKIP LOG · BATTERY / THERMAL / APP-NAP") {
        BzrCodeBlock(text: """
          2026-04-30T22:00  refresh-outdated   skipped  reason=on-battery
          2026-04-30T18:00  refresh-advisories ok       fetched=143 entries
          2026-04-30T17:00  refresh-outdated   ok       12 outdated
          2026-04-30T13:00  refresh-outdated   skipped  reason=app-nap
          """)
      }
    }
    .accessibilityIdentifier("pane.schedule")
  }
}

// MARK: - age Keys

struct AgeKeysPane: View {
  var body: some View {
    PowerScaffold(eyebrow: "POWER / AGE / X25519 · AgeBroker · KeychainBroker",
                  title: "AGE KEYS.",
                  subtitle: "Local identity at ~/.config/chezmoi/key.txt. Public recipient shared with writers. Sojourn never commits the private key.") {
      BzrCard(eyebrow: "LOCAL IDENTITY") {
        BzrCodeBlock(text: """
          # ~/.config/chezmoi/key.txt
          AGE-SECRET-KEY-1QZRL7K...REDACTED...

          # public recipient
          age1qzr...l7kq
          """)
      }
      BzrCard(eyebrow: "RECIPIENTS · .sojourn/recipients.txt") {
        VStack(alignment: .leading, spacing: 8) {
          recipientRow("work-mbp", "age1qzr...l7kq", true)
          recipientRow("personal-mini", "age1abc...x4yz", false)
          recipientRow("ci-runner", "age1def...m9np", false)
        }
      }
      BzrCallout(
        title: "Identity rotation",
        kind: .warn,
        bodyText: "Generate new keypair → publish new recipient → writer re-encrypts on next push → revoke old recipient. v1.0 documents the steps; v1.1 wires the wizard."
      )
    }
    .accessibilityIdentifier("pane.age")
  }

  @ViewBuilder
  private func recipientRow(_ machine: String, _ key: String, _ self_: Bool) -> some View {
    HStack(spacing: 10) {
      StatusDot(kind: self_ ? .lime : .ok)
      Text(machine)
        .font(.bzrBody(size: 12, weight: .semibold))
        .foregroundStyle(Color.txtPrimary)
        .frame(width: 130, alignment: .leading)
      Text(key)
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color.txtTertiary)
      Spacer()
      if self_ { BzrBadge(text: "THIS MAC", kind: .lime) }
    }
  }
}

// MARK: - chezmoi Templates

struct ChezmoiTemplatesPane: View {
  var body: some View {
    PowerScaffold(eyebrow: "POWER / TEMPLATES / chezmoi data · managed · diff",
                  title: "TEMPLATES.",
                  subtitle: "Per-host conditionals + variables. Five canonical commands Sojourn invokes; the JSON shape Sojourn parses.") {
      BzrCard(eyebrow: "5 COMMANDS") {
        BzrCodeBlock(text: """
          chezmoi managed --format=json
          chezmoi status
          chezmoi diff --no-pager --color=false
          chezmoi merge <path>
          chezmoi apply --force
          chezmoi update
          """)
      }
      BzrCard(eyebrow: "CHEZMOI DATA · this-host") {
        BzrCodeBlock(text: """
          {
            "chezmoi": {
              "hostname": "work-mbp",
              "os":       "darwin",
              "username": "you",
              "kernel":   "Darwin 24.6.0"
            },
            "git": { "name": "you", "email": "you@example.com" }
          }
          """)
      }
      BzrCard(eyebrow: ".CHEZMOIIGNORE · BOILERPLATE") {
        BzrCodeBlock(text: """
          known_hosts*
          .DS_Store
          *.swp
          .config/sojourn/cache/
          """)
      }
    }
    .accessibilityIdentifier("pane.chezmoi-templates")
  }
}

// MARK: - gitleaks Rules

struct GitleaksRulesPane: View {
  var body: some View {
    PowerScaffold(eyebrow: "POWER / RULES / gitleaks 8.30.1 · MIT · bundled",
                  title: "RULES & ALLOWLIST.",
                  subtitle: "142 builtin patterns. Per-repo allowlist with optional expiry. High-confidence categories drive 5-second lockout.") {
      BzrCard(eyebrow: "BUILTIN · 142 PATTERNS") {
        VStack(alignment: .leading, spacing: 6) {
          ruleRow("aws-access-token", "HIGH", .tierE)
          ruleRow("github-pat", "HIGH", .tierE)
          ruleRow("openai-api-key", "HIGH", .tierE)
          ruleRow("stripe-access-token", "HIGH", .tierE)
          ruleRow("anthropic-api-key", "HIGH", .tierE)
          ruleRow("slack-bot-token", "HIGH", .tierE)
          ruleRow("generic-api-key", "MED", .tierC)
          ruleRow("private-key-rsa", "HIGH", .tierE)
        }
      }
      BzrCard(eyebrow: "ALLOWLIST · .gitleaks.toml (repo)") {
        BzrCodeBlock(text: """
          [allowlist]
            description = "test fixtures"
            paths = [ "tests/fixtures/.+", "snapshots/.+\\.snap" ]
            regexes = [ "REDACTED_\\\\w+" ]
            commits = [ "abc123 # docs example" ]
          """)
      }
    }
    .accessibilityIdentifier("pane.gitleaks-rules")
  }

  @ViewBuilder
  private func ruleRow(_ id: String, _ severity: String, _ kind: BzrBadgeKind) -> some View {
    HStack(spacing: 10) {
      Text(id).font(.bzrMono(size: 11)).foregroundStyle(Color.txtPrimary)
      Spacer()
      BzrBadge(text: severity, kind: kind)
    }
  }
}

// MARK: - Authorization

struct AuthorizationPane: View {
  var body: some View {
    PowerScaffold(eyebrow: "POWER / AUTH / TCC · FDA canary · Authorization.framework",
                  title: "PERMISSIONS.",
                  subtitle: "Full Disk Access detection via canary probe. brew installer Authorization prompt for /usr/sbin/installer. No private SPI.") {
      BzrCard(eyebrow: "FDA CANARY") {
        VStack(alignment: .leading, spacing: 8) {
          HStack { StatusDot(kind: .ok); Text("Probe target: /Library/Preferences/com.apple.TimeMachine.plist").font(.bzrMono(size: 11)).foregroundStyle(Color.txtPrimary); Spacer() }
          HStack { Text("Result").font(.bzrMono(size: 10)).foregroundStyle(Color.txtTertiary).frame(width: 80, alignment: .leading); BzrBadge(text: "GRANTED", kind: .success); Spacer() }
          Text("Granted: sandboxed plist sync available. Denied: layer 3 disabled, layer 1 + 2 still work.")
            .font(.bzrBody(size: 11))
            .foregroundStyle(Color.txtSecondary)
        }
      }
      BzrCard(eyebrow: "BREW INSTALLER · Authorization.framework") {
        BzrCodeBlock(text: """
          AuthorizationCreate(rights, env, [.interactionAllowed, .preAuthorize])
          AuthorizationExecuteWithPrivileges(
            "/usr/sbin/installer",
            ["-pkg", brew.pkg, "-target", "/"]
          )
          # signed pkg only · no curl|bash
          """)
      }
    }
    .accessibilityIdentifier("pane.authorization")
  }
}

// MARK: - Manager Detail

struct ManagerDetailPane: View {
  var body: some View {
    PowerScaffold(eyebrow: "POWER / MANAGER / Cargo as the template",
                  title: "MANAGER · CARGO.",
                  subtitle: "Per-ecosystem deep view. Raw brew bundle output, advisory bypass, pin syntax, ignore-on-fail semantics.") {
      BzrCard(eyebrow: "RAW · brew bundle list --all --cargo") {
        BzrCodeBlock(text: """
          [
            {
              "manager": "cargo",
              "name":    "cargo-watch",
              "purl":    "pkg:cargo/cargo-watch@8.4.1",
              "current": "8.4.1",
              "latest":  "8.5.3",
              "advisory": null
            }
          ]
          """)
      }
      BzrCard(eyebrow: "PIN SYNTAX · packages.toml") {
        BzrCodeBlock(text: """
          [cargo]
          ripgrep = "^14.0"
          fd      = ">=10.0,<11"
          eza     = "*"
          """)
      }
      BzrCard(eyebrow: "ADVISORY BYPASS") {
        Text("OSV/GHSA delta-fetch via modified_id.csv. Cooldown skipped on hit; user picks update or pin. Empty when no findings.")
          .font(.bzrBody(size: 12))
          .foregroundStyle(Color.txtSecondary)
      }
    }
    .accessibilityIdentifier("pane.manager-detail")
  }
}

// MARK: - Backups

struct BackupsPane: View {
  private struct Backup: Identifiable {
    let id: String
    let when: String
    let op: String
    let size: String
  }

  private var backups: [Backup] {
    [
      .init(id: "2026-04-30T19-34-pre-push", when: "2h ago", op: "push", size: "12 MB"),
      .init(id: "2026-04-30T08-12-pre-pull", when: "13h ago", op: "pull", size: "8 MB"),
      .init(id: "2026-04-29T19-02-pre-apply", when: "1d ago", op: "apply", size: "4 MB"),
      .init(id: "2026-04-28T14-30-sync.pull", when: "2d ago", op: "pull", size: "10 MB"),
      .init(id: "2026-04-26T11-45-pre-cleanup", when: "4d ago", op: "cleanup", size: "2 MB")
    ]
  }

  var body: some View {
    PowerScaffold(eyebrow: "POWER / BACKUPS / SnapshotService · BackupsDirectory",
                  title: "BACKUPS.",
                  subtitle: "Pre-op tarballs at ~/Library/Application Support/Sojourn/backups/. 30-day retention. gc() runs on app launch.") {
      BzrCard(eyebrow: "INDEX · 5 RECENT") {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(backups) { b in
            HStack(spacing: 10) {
              Image(systemName: "archivebox.fill").font(.system(size: 11)).foregroundStyle(Color.bzrLime)
              VStack(alignment: .leading, spacing: 2) {
                Text(b.id).font(.bzrMono(size: 11)).foregroundStyle(Color.txtPrimary)
                Text("\(b.when) · op=\(b.op)").font(.bzrMono(size: 10)).foregroundStyle(Color.txtTertiary)
              }
              Spacer()
              Text(b.size).font(.bzrMono(size: 10)).foregroundStyle(Color.txtTertiary)
              Button {} label: { Text("Restore").font(.bzrMono(size: 11)) }
                .buttonStyle(GlassCapsuleButtonStyle())
            }
          }
        }
      }
      BzrCallout(
        title: "Restore writes a NEW backup first",
        kind: .info,
        bodyText: "Restoring is itself a destructive op. Sojourn snapshots the working tree before applying the chosen backup, so you can roll back the rollback."
      )
    }
    .accessibilityIdentifier("pane.backups")
  }
}

// MARK: - Defaults Discover (deferred to v1.1 per impl-plan §1.5)

struct DefaultsDiscoverPane: View {
  var body: some View {
    PowerScaffold(eyebrow: "POWER / DISCOVER / record-session · v1.1 deferred",
                  title: "DISCOVER.",
                  subtitle: "Records changes you make in System Settings, then reports the cfprefsd-touched keys. v1.1 ships the recorder; v1.0 documents the model.") {
      BzrCallout(
        title: "Deferred per docs/explain/discover-pane.md",
        kind: .warn,
        bodyText: "Per process/open-questions.md §4, Discover ships in v1.1 as a record-session model — not a continuous cfprefsd watcher. v1.0 lists this surface so the sidebar route exists."
      )
      BzrCard(eyebrow: "MODEL · RECORD SESSION") {
        BzrCodeBlock(text: """
          1. User clicks "Start recording" in this pane.
          2. Sojourn snapshots all tracked plists.
          3. User opens System Settings, makes their change.
          4. User clicks "Stop". Sojourn diffs each plist.
          5. New keys surface as "would you like to track this?"
          6. User picks domains; they join packages.toml's preferences list.
          """)
      }
    }
    .accessibilityIdentifier("pane.defaults-discover")
  }
}

// MARK: - Repo Setup

struct RepoSetupPane: View {
  var body: some View {
    PowerScaffold(eyebrow: "POWER / REPO / GitService · GitHubDeviceAuth",
                  title: "REPO SETUP.",
                  subtitle: "Bring-your-own remote default. Optional GitHub Device Flow auth. GPG / SSH signing, branch policy, commit message template.") {
      BzrCard(eyebrow: "REMOTE") {
        VStack(alignment: .leading, spacing: 8) {
          TextField("git@github.com:you/my-mac.git", text: .constant("git@github.com:you/my-mac.git"))
            .textFieldStyle(.plain)
            .font(.bzrMono(size: 12))
            .foregroundStyle(Color.txtPrimary)
            .padding(8)
            .background(Color.black.opacity(0.25))
            .overlay(
              RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.hairline, lineWidth: 0.5)
            )
          HStack(spacing: 8) {
            BzrBadge(text: "REACHABLE", kind: .success)
            BzrBadge(text: "SSH", kind: .mute)
            BzrBadge(text: "git-credential-osxkeychain", kind: .mute)
          }
        }
      }
      BzrCard(eyebrow: "SIGNING") {
        VStack(alignment: .leading, spacing: 6) {
          signingRow("GPG (gpg-agent)", true)
          signingRow("SSH (ssh-agent)", false)
          signingRow("Apple Notary", false)
        }
      }
      BzrCard(eyebrow: "COMMIT MESSAGE TEMPLATE") {
        BzrCodeBlock(text: """
          {{ .op }}: {{ .summary }}

          Sojourn-Op: {{ .op }}
          Sojourn-Machine: {{ .machine }}
          Sojourn-Snapshot: {{ .snapshot }}
          """)
      }
    }
    .accessibilityIdentifier("pane.repo-setup")
  }

  @ViewBuilder
  private func signingRow(_ label: String, _ enabled: Bool) -> some View {
    HStack {
      StatusDot(kind: enabled ? .lime : .ok)
      Text(label).font(.bzrBody(size: 12)).foregroundStyle(Color.txtPrimary)
      Spacer()
      BzrToggle(isOn: .constant(enabled))
    }
  }
}

// MARK: - Shared scaffold

private struct PowerScaffold<Content: View>: View {
  let eyebrow: String
  let title: String
  let subtitle: String
  @ViewBuilder let content: () -> Content

  init(eyebrow: String, title: String, subtitle: String, @ViewBuilder content: @escaping () -> Content) {
    self.eyebrow = eyebrow
    self.title = title
    self.subtitle = subtitle
    self.content = content
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: eyebrow).padding(.top, 8)
        Text(title)
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text(subtitle)
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)
        content()
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
