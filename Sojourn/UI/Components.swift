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
      Spacer()
      Button {
        // Wired in Phase 7 once SyncCoordinator is injected into AppStore.
      } label: {
        Label("Pull", systemImage: "arrow.down.circle")
      }
      .accessibilityIdentifier("pushpull.pull")

      Button {
        // Wired in Phase 7 once SyncCoordinator is injected into AppStore.
      } label: {
        Label("Push", systemImage: "arrow.up.circle")
      }
      .accessibilityIdentifier("pushpull.push")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
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
