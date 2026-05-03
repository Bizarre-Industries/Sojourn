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

// MARK: - Liquid Glass toolbar (Stage 2 chrome)
//
// Translation of `chrome.jsx` Toolbar (lines 69-84). Eyebrow above the
// title, glass search field on the left, last-sync badge + Push/Pull
// on the right. Replaces `PushPullBar`'s footprint in the new shell.

struct SojournToolbar: View {
  @Environment(AppStore.self) private var store
  let title: String
  let eyebrow: String

  @State private var query: String = ""

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(eyebrow)
          .font(.bzrTinyEyebrow)
          .tracking(1.6)
          .textCase(.uppercase)
          .foregroundStyle(Color.txtTertiary)
        HStack(spacing: 8) {
          SojournMenuBarIconView(size: 14, color: .bzrLime)
          Text(title)
            .font(.bzrBody(size: 15, weight: .bold))
            .foregroundStyle(Color.txtPrimary)
        }
      }

      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Color.txtTertiary)
        TextField("Search…", text: $query)
          .textFieldStyle(.plain)
          .font(.bzrBody(size: 12))
          .foregroundStyle(Color.txtPrimary)
        Text("⌘F")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .frame(width: 240)
      .background(
        Capsule()
          .fill(Color.adaptiveLighten(0.05))
          .overlay(Capsule().stroke(Color.hairline, lineWidth: 0.5))
      )
      .padding(.leading, 8)

      Spacer()

      if let last = store.settings.lastSyncTime {
        HStack(spacing: 6) {
          StatusDot(kind: .lime)
          Text("Synced \(last.formatted(.relative(presentation: .named)))")
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
        }
      } else {
        Text("Never synced")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.txtTertiary)
      }

      Button {
        Task { await store.sync?.pull() }
      } label: {
        Label("Pull", systemImage: "arrow.down")
      }
      .buttonStyle(GlassCapsuleButtonStyle())
      .disabled(store.sync == nil)
      .accessibilityIdentifier("toolbar.pull")

      Button {
        Task { await store.sync?.push(message: "sojourn: auto-sync") }
      } label: {
        Label("Push", systemImage: "arrow.up")
      }
      .buttonStyle(GlassPrimaryButtonStyle())
      .disabled(store.sync == nil)
      .accessibilityIdentifier("toolbar.push")
    }
    .padding(.horizontal, 16)
    .frame(height: BzrSpacing.toolbarHeight)
    .background(Color.glassToolbar)
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
    VStack(alignment: .leading, spacing: 0) {
      // Brand strip
      HStack(spacing: 8) {
        SojournMenuBarIconView(size: 14, color: .bzrLime)
        Text("SOJOURN")
          .font(.bzrStencil(size: 14, weight: .heavy))
          .tracking(1.6)
          .foregroundStyle(Color.txtPrimary)
        Spacer()
        StatusDot(kind: store.sync == nil ? .warn : .lime)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .overlay(
        Rectangle().fill(Color.hairline).frame(height: 0.5),
        alignment: .bottom
      )

      // Status row
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(machineName.uppercased())
            .font(.bzrMono(size: 10, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Color.bzrLime)
          Text("·")
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
          Text(syncRelative)
            .font(.bzrMono(size: 10))
            .foregroundStyle(Color.txtTertiary)
        }
        Text(store.sync == nil ? "Sync not configured" : "Writer · clean")
          .font(.bzrBody(size: 11))
          .foregroundStyle(Color.txtSecondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)

      // Quick actions
      VStack(spacing: 6) {
        Button {
          Task { await store.sync?.pull() }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "arrow.down")
              .font(.system(size: 10, weight: .semibold))
            Text("Pull")
            Spacer()
          }
        }
        .buttonStyle(GlassCapsuleButtonStyle())
        .disabled(store.sync == nil)
        .accessibilityIdentifier("menubar.pull")

        Button {
          Task { await store.sync?.push(message: "sojourn: menu-bar push") }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "arrow.up")
              .font(.system(size: 10, weight: .semibold))
            Text("Push")
            Spacer()
          }
        }
        .buttonStyle(GlassPrimaryButtonStyle())
        .disabled(store.sync == nil)
        .accessibilityIdentifier("menubar.push")
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 6)

      // Footer
      VStack(spacing: 0) {
        Rectangle().fill(Color.hairline).frame(height: 0.5)
        HStack(spacing: 6) {
          Button("Open Sojourn…") {
            NSApp.activate(ignoringOtherApps: true)
          }
          .buttonStyle(GlassGhostButtonStyle())
          .accessibilityIdentifier("menubar.open")
          Spacer()
          Button("Quit") { NSApp.terminate(nil) }
            .buttonStyle(GlassGhostButtonStyle())
            .accessibilityIdentifier("menubar.quit")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
      }
    }
    .frame(width: 300, alignment: .leading)
  }

  private var machineName: String {
    Host.current().localizedName ?? "this-mac"
  }

  private var syncRelative: String {
    if let last = store.settings.lastSyncTime {
      return last.formatted(.relative(presentation: .named))
    }
    return "never synced"
  }
}
