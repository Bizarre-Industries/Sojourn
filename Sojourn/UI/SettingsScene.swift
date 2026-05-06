// Sojourn — SettingsScene
//
// The macOS-standard Settings tab set. General / Sync / Security / About.
// See docs/reference/architecture.md.

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
    .frame(minWidth: 520, idealWidth: 560, minHeight: 360, idealHeight: 400)
    .accessibilityIdentifier("settings.root")
  }
}

struct GeneralSettingsTab: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    Form {
      Toggle("Dry-run destructive operations by default", isOn: dryRunBinding)
        .accessibilityIdentifier("settings.dryRun")
      Toggle("Open Sojourn at login", isOn: loginItemBinding)
        .accessibilityIdentifier("settings.openAtLogin")
      VStack(alignment: .leading, spacing: 4) {
        Text("Login item: \(store.loginItemStatus.label)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(store.loginItemMessage ?? store.loginItemStatus.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .accessibilityIdentifier("settings.loginItemStatus")
      Picker("Install source", selection: installSourceBinding) {
        Text(InstallSource.unknown.label).tag(InstallSource.unknown)
        Text(InstallSource.dmg.label).tag(InstallSource.dmg)
        Text(InstallSource.cask.label).tag(InstallSource.cask)
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("settings.installSource")
      Text(
        store.settings.effectiveInstallSource == .cask
          ? "Homebrew handles updates for this install."
          : "Sparkle handles updates for this install."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .task { await store.refreshLoginItemStatus() }
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

  private var loginItemBinding: Binding<Bool> {
    Binding(
      get: { store.loginItemStatus.isEnabledForToggle },
      set: { newValue in
        Task { await store.setLoginItemEnabled(newValue) }
      }
    )
  }

  private var installSourceBinding: Binding<InstallSource> {
    Binding(
      get: { store.settings.effectiveInstallSource },
      set: { newValue in
        Task {
          var snap = await store.settingsStore.value
          snap.installSource = newValue
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
      TextField(
        "Remote repo URL", text: $draftURL, prompt: Text("git@github.com:you/sojourn-data.git")
      )
      .accessibilityIdentifier("settings.remoteURL")
      HStack {
        Button("Save + clone") {
          Task {
            var snap = await store.settingsStore.value
            snap.remoteRepoURL = draftURL
            try? await store.settingsStore.replace(snap)
            await store.reloadFromDisk()
            let localRepo = store.paths.config.appendingPathComponent(
              "sojourn-data", isDirectory: true)
            let shouldClone = !FileManager.default.fileExists(atPath: localRepo.path)
            if shouldClone, let git = store.git {
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
          .lineLimit(1)
          .truncationMode(.middle)
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
      if let gitleaksConfigURL = URL(
        string:
          "https://github.com/Bizarre-Industries/Sojourn/blob/main/Sojourn/Resources/data/gitleaks.toml"
      ) {
        Link("Review data/gitleaks.toml", destination: gitleaksConfigURL)
      }
    }
  }
}

struct AboutTab: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Sojourn").font(.title2.bold())
      Text("GPL-3.0-or-later. See LICENSE.")
        .font(.caption).foregroundStyle(.secondary)
      if let sourceURL = URL(string: "https://github.com/Bizarre-Industries/Sojourn") {
        Link("Source", destination: sourceURL)
      }
      if let thirdPartyURL = URL(
        string: "https://github.com/Bizarre-Industries/Sojourn/blob/main/THIRDPARTY.md"
      ) {
        Link("THIRDPARTY.md", destination: thirdPartyURL)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
