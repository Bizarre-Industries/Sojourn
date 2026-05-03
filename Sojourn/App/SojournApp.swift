// Sojourn — App entry
//
// @main. Owns the root AppStore. Injects it into the environment for the
// MainWindow scene, the MenuBarExtra, and the Settings scene. See
// docs/ARCHITECTURE.md §11 and CLAUDE.md ("Do not use @State to hold the
// root AppStore").

import SwiftUI

@main
struct SojournApp: App {
  @State private var storeBox = AppStoreBox()

  var body: some Scene {
    // The app supports BOTH macOS appearances. The Color tokens in
    // Color+Sojourn.swift adapt per-appearance via NSColor's
    // dynamic-provider; surfaces, hairlines, and text auto-resolve.
    WindowGroup {
      Group {
        if let store = storeBox.store {
          MainWindowView()
            .environment(store)
            .task {
              await store.reloadFromDisk()
              await store.bootstrap.probe()
              await store.refreshManagers()
            }
        } else if storeBox.initError != nil {
          ContentUnavailableView(
            "Sojourn cannot start",
            systemImage: "exclamationmark.triangle",
            description: Text(storeBox.initError ?? "AppStore failed to bootstrap.")
          )
        } else {
          ProgressView("Starting Sojourn…")
            .task { await storeBox.bootstrap() }
        }
      }
    }

    MenuBarExtra {
      if let store = storeBox.store {
        MenuBarRootView().environment(store)
      } else {
        Text("Sojourn not ready").padding(12)
      }
    } label: {
      // The Sojourn S-in-rounded-square mark, drawn directly as an
      // NSImage with isTemplate=true. AppKit re-tints to the menubar
      // foreground (dark in light menubar, white in dark menubar).
      Image(nsImage: sojournMenuBarTemplateImage(size: 18))
    }
    .menuBarExtraStyle(.window)

    SwiftUI.Settings {
      if let store = storeBox.store {
        SettingsRoot().environment(store)
      } else {
        Text("Sojourn not ready").padding(20)
      }
    }

    Window("Architecture", id: "architecture") {
      ArchitectureView()
    }
    .windowResizability(.contentSize)
    .commands {
      CommandGroup(after: .help) {
        ArchitectureMenuItem()
      }
    }
  }
}

private struct ArchitectureMenuItem: View {
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button("Architecture") {
      openWindow(id: "architecture")
    }
    .keyboardShortcut("a", modifiers: [.command, .option])
  }
}

/// Initialization holder. AppStore is @MainActor-isolated so constructing
/// it from a plain stored property initializer needs an actor-isolated
/// wrapper.
@Observable
@MainActor
final class AppStoreBox {
  private(set) var store: AppStore?
  private(set) var initError: String?

  init() {}

  func bootstrap() async {
    do {
      self.store = try await AppStore.live()
    } catch {
      self.initError = "\(error)"
    }
  }
}
