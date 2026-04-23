import SwiftUI

/// @main app entry. See docs/ARCHITECTURE.md section 11.
@main
struct SojournApp: App {
  @State private var store = AppStore()

  var body: some Scene {
    WindowGroup {
      MainWindowView()
        .environment(store)
    }

    MenuBarExtra("Sojourn", systemImage: "shippingbox.fill") {
      MenuBarRootView()
        .environment(store)
    }
    .menuBarExtraStyle(.window)
  }
}
