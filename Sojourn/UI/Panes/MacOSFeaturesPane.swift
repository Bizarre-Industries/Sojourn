// Sojourn — MacOSFeaturesPane (v0.2 step 7)
//
// First-class UI over `MacOSFeaturesService`. Touch ID for sudo,
// Finder defaults, keyboard repeat, screencapture location/format,
// login window text. Dock editor + hotkey editor deferred to v0.3 per
// docs/process/plans/v0.2-plan.md §"Out of scope".

import Foundation
import SwiftUI

internal struct MacOSFeaturesPane: View {
  @Environment(AppStore.self) private var store
  @State private var touchIDEnabled: Bool = false
  @State private var finderDefaults: [FinderDefault: Bool] = [:]
  @State private var actionError: String?
  @State private var initialKeyRepeat: Int = 25
  @State private var keyRepeatRate: Int = 6
  @State private var screencapturePath: String = "~/Desktop"
  @State private var screencaptureType: String = "png"

  internal var body: some View {
    Form {
      Section("Touch ID for sudo") {
        Toggle(
          "Insert pam_tid.so into /etc/pam.d/sudo",
          isOn: $touchIDEnabled
        )
        .onChange(of: touchIDEnabled) { _, newValue in
          if newValue { Task { await enableTouchID() } }
        }
        Text("v0.2 routes through `osascript ... with administrator privileges` (single password prompt). v0.3 ships a privileged helper at `/Library/PrivilegedHelperTools/`.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Finder") {
        ForEach(FinderDefault.allCases) { key in
          let isOn = Binding<Bool>(
            get: { finderDefaults[key] ?? false },
            set: { newValue in
              finderDefaults[key] = newValue
              Task { await setFinder(key, on: newValue) }
            }
          )
          Toggle(label(for: key), isOn: isOn)
        }
      }

      Section("Keyboard repeat (NSGlobalDomain)") {
        Stepper("Initial: \(initialKeyRepeat) (×15 ms)",
                value: $initialKeyRepeat, in: 10...120, step: 5)
        Stepper("Repeat rate: \(keyRepeatRate) (×15 ms)",
                value: $keyRepeatRate, in: 1...60)
        Button("Apply keyboard repeat") {
          Task { await applyKeyRepeat() }
        }
      }

      Section("Screencapture") {
        TextField("Save location (path)", text: $screencapturePath)
        Picker("Format", selection: $screencaptureType) {
          Text("png").tag("png")
          Text("jpg").tag("jpg")
          Text("pdf").tag("pdf")
          Text("tiff").tag("tiff")
        }
        Button("Apply screencapture settings") {
          Task { await applyScreencapture() }
        }
      }

      if let actionError {
        Section {
          Text(actionError)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.red)
        }
      }
    }
    .padding(24)
    .formStyle(.grouped)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("pane.macosFeatures")
    .task { await reload() }
  }

  // MARK: - Helpers

  private func label(for key: FinderDefault) -> String {
    switch key {
    case .showAllExtensions:  return "Show all filename extensions"
    case .showPathbar:        return "Show path bar"
    case .showStatusBar:      return "Show status bar"
    case .showHiddenFiles:    return "Show hidden files (Cmd-Shift-.)"
    case .sortFoldersFirst:   return "Keep folders on top when sorting"
    case .preferredViewStyle: return "List view by default (off = icon view)"
    }
  }

  // MARK: - Actions

  private func reload() async {
    let svc = MacOSFeaturesService(runner: store.runner)
    self.touchIDEnabled = svc.isTouchIDForSudoEnabled()

    var loaded: [FinderDefault: Bool] = [:]
    for key in FinderDefault.allCases {
      loaded[key] = (try? await svc.readFinderDefault(key)) ?? false
    }
    self.finderDefaults = loaded
  }

  private func enableTouchID() async {
    let svc = MacOSFeaturesService(runner: store.runner)
    do {
      try await svc.enableTouchIDForSudo()
    } catch {
      actionError = "Touch ID for sudo: \(error)"
      touchIDEnabled = svc.isTouchIDForSudoEnabled()
    }
  }

  private func setFinder(_ key: FinderDefault, on: Bool) async {
    let svc = MacOSFeaturesService(runner: store.runner)
    do {
      try await svc.setFinderDefault(key, on: on)
      actionError = nil
    } catch {
      actionError = "Finder \(key.rawValue): \(error)"
    }
  }

  private func applyKeyRepeat() async {
    let svc = MacOSFeaturesService(runner: store.runner)
    do {
      try await svc.setKeyRepeat(initial: initialKeyRepeat, repeatRate: keyRepeatRate)
      actionError = nil
    } catch {
      actionError = "KeyRepeat: \(error)"
    }
  }

  private func applyScreencapture() async {
    let svc = MacOSFeaturesService(runner: store.runner)
    do {
      let expanded = NSString(string: screencapturePath).expandingTildeInPath
      try await svc.setScreencaptureLocation(URL(fileURLWithPath: expanded))
      try await svc.setScreencaptureType(screencaptureType)
      actionError = nil
    } catch {
      actionError = "Screencapture: \(error)"
    }
  }
}
