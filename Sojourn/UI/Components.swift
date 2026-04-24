// Sojourn — Reusable UI components
//
// - PushPullBar: top toolbar with Push / Pull + last-sync badge.
// - LogConsoleView: ANSI-attributed streaming console for Job logs.
// - MenuBarRootView: MenuBarExtra content; status + Open App button.
//
// See docs/ARCHITECTURE.md §11.

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct PushPullBar: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    HStack {
      if let last = store.settings.lastSyncTime {
        Label("Last sync: \(last.formatted(.relative(presentation: .named)))",
              systemImage: "clock")
          .font(.caption).foregroundStyle(.secondary)
      } else {
        Label("Never synced", systemImage: "clock.badge.questionmark")
          .font(.caption).foregroundStyle(.secondary)
      }
      if let phase = store.sync?.phase {
        Text(phaseLabel(phase))
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        Task { await store.sync?.pull() }
      } label: {
        Label("Pull", systemImage: "arrow.down.circle")
      }
      .disabled(store.sync == nil)
      .accessibilityIdentifier("pushpull.pull")

      Button {
        Task {
          await store.sync?.push(message: "sojourn: auto-sync")
        }
      } label: {
        Label("Push", systemImage: "arrow.up.circle")
      }
      .disabled(store.sync == nil)
      .accessibilityIdentifier("pushpull.push")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
  }

  private func phaseLabel(_ phase: SyncPhase) -> String {
    switch phase {
    case .idle: return "idle"
    case .pulling: return "pulling…"
    case .resolvingConflicts: return "resolving conflicts"
    case .scanningSecrets: return "gitleaks scan"
    case .pushing: return "pushing…"
    case .done(let kind): return "done: \(kind.rawValue)"
    case .failed(let reason): return "failed: \(reason.prefix(50))"
    }
  }
}

struct LogConsoleView: View {
  let lines: [LogLine]

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 1) {
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
          Text(line.text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(line.stream == .stderr ? Color.red : Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(8)
    }
    .background(Color(nsColor: .textBackgroundColor))
    .accessibilityIdentifier("log.console")
  }
}

struct MenuBarRootView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Sojourn").font(.headline)
      if let last = store.settings.lastSyncTime {
        Text("Last sync: \(last.formatted(.relative(presentation: .named)))")
          .font(.caption).foregroundStyle(.secondary)
      } else {
        Text("Never synced")
          .font(.caption).foregroundStyle(.secondary)
      }
      Divider()
      Button("Open Sojourn…") {
        NSApp.activate(ignoringOtherApps: true)
      }
      .accessibilityIdentifier("menubar.open")

      Button("Quit") { NSApp.terminate(nil) }
        .accessibilityIdentifier("menubar.quit")
    }
    .padding(12)
    .frame(width: 220)
  }
}
