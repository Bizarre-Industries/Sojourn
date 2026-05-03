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
    // The Sojourn design (Claude Design handoff:
    // docs/design/handoff/extracted/sojourn/project/styles.css) is
    // dark-only — Tahoe Liquid Glass surfaces over a deep wallpaper,
    // brand lime as the only bright accent. There are no light-mode
    // tokens. Force dark on every Scene so the app is legible
    // regardless of the user's System Settings → Appearance choice.
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
      .preferredColorScheme(.dark)
    }

    MenuBarExtra {
      Group {
        if let store = storeBox.store {
          MenuBarRootView().environment(store)
        } else {
          Text("Sojourn not ready").padding(12)
        }
      }
      .preferredColorScheme(.dark)
    } label: {
      // The Sojourn S-in-rounded-square mark, drawn directly as an
      // NSImage with isTemplate=true. We bypass MenuBarExtra(label:)'s
      // SwiftUI->NSImage conversion (which silently rasterizes Path
      // shapes badly) and hand AppKit the template image ourselves.
      // AppKit re-tints to the menubar foreground (white in dark
      // menubar, near-black in light menubar).
      Image(nsImage: sojournMenuBarTemplateImage(size: 18))
    }
    .menuBarExtraStyle(.window)

    SwiftUI.Settings {
      Group {
        if let store = storeBox.store {
          SettingsRoot().environment(store)
        } else {
          Text("Sojourn not ready").padding(20)
        }
      }
      .preferredColorScheme(.dark)
    }

    Window("Architecture", id: "architecture") {
      ArchitectureView()
        .preferredColorScheme(.dark)
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
