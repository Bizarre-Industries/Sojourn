// Sojourn — SettingsScene
//
// The macOS-standard Settings tab set. General / Sync / Security / About.
// See docs/ARCHITECTURE.md §11.

import SwiftUI

struct SettingsRoot: View {
  var body: some View {
    TabView {
      GeneralSettingsTab()
        .tabItem { Label("General", systemImage: "gearshape") }
      SyncSettingsTab()
        .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
      SecuritySettingsTab()
        .tabItem { Label("Security", systemImage: "lock.shield") }
      AboutTab()
        .tabItem { Label("About", systemImage: "info.circle") }
    }
    .padding(20)
    .frame(width: 520, height: 360)
    .accessibilityIdentifier("settings.root")
  }
}

struct GeneralSettingsTab: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    Form {
      Toggle("Dry-run destructive operations by default", isOn: dryRunBinding)
        .accessibilityIdentifier("settings.dryRun")
    }
  }

  private var dryRunBinding: Binding<Bool> {
    Binding(
      get: { store.settings.dryRunByDefault },
      set: { newValue in
        Task {
          var snap = await store.settingsStore.value
          snap.dryRunByDefault = newValue
          try? await store.settingsStore.replace(snap)
          await store.reloadFromDisk()
        }
      }
    )
  }
}

struct SyncSettingsTab: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    Form {
      LabeledContent("Remote repo URL") {
        Text(store.settings.remoteRepoURL ?? "not configured")
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      Toggle("Cooldown gate enabled", isOn: cooldownBinding)
        .accessibilityIdentifier("settings.cooldown")
    }
  }

  private var cooldownBinding: Binding<Bool> {
    Binding(
      get: { store.settings.cooldownEnabled },
      set: { newValue in
        Task {
          var snap = await store.settingsStore.value
          snap.cooldownEnabled = newValue
          try? await store.settingsStore.replace(snap)
          await store.reloadFromDisk()
        }
      }
    )
  }
}

struct SecuritySettingsTab: View {
  var body: some View {
    Form {
      Text("Secret-scanning is bundled via gitleaks in Contents/Resources/bin.")
        .font(.caption).foregroundStyle(.secondary)
      Link(
        "Review data/gitleaks.toml",
        destination: URL(string: "https://github.com/Bizarre-Industries/Sojourn/blob/main/Sojourn/Resources/data/gitleaks.toml")!
      )
    }
  }
}

struct AboutTab: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Sojourn").font(.title2.bold())
      Text("GPL-3.0-or-later. See LICENSE.")
        .font(.caption).foregroundStyle(.secondary)
      Link(
        "Source",
        destination: URL(string: "https://github.com/Bizarre-Industries/Sojourn")!
      )
      Link(
        "THIRDPARTY.md",
        destination: URL(string: "https://github.com/Bizarre-Industries/Sojourn/blob/main/THIRDPARTY.md")!
      )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
