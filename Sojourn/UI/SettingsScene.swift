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
  @State private var draftURL: String = ""

  var body: some View {
    Form {
      TextField("Remote repo URL", text: $draftURL, prompt: Text("git@github.com:you/sojourn-data.git"))
        .accessibilityIdentifier("settings.remoteURL")
      HStack {
        Button("Save + clone") {
          Task {
            var snap = await store.settingsStore.value
            snap.remoteRepoURL = draftURL
            try? await store.settingsStore.replace(snap)
            await store.reloadFromDisk()
            let localRepo = store.paths.config.appendingPathComponent("sojourn-data", isDirectory: true)
            if !FileManager.default.fileExists(atPath: localRepo.path),
               let git = store.git {
              try? await git.clone(url: draftURL, dest: localRepo)
            }
            if FileManager.default.fileExists(atPath: localRepo.path) {
              store.configureSync(repoURL: localRepo)
            }
          }
        }
        .disabled(draftURL.isEmpty)
        .accessibilityIdentifier("settings.saveRemote")
        Spacer()
        Text(store.settings.remoteRepoURL ?? "not configured")
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      Toggle("Cooldown gate enabled", isOn: cooldownBinding)
        .accessibilityIdentifier("settings.cooldown")
    }
    .onAppear {
      if draftURL.isEmpty {
        draftURL = store.settings.remoteRepoURL ?? ""
      }
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
