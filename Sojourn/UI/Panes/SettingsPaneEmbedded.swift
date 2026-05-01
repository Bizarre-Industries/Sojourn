// Sojourn — SettingsPaneEmbedded

import SwiftUI

struct SettingsPaneEmbedded: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        EyebrowLabel(text: "APP / SETTINGS")
          .padding(.top, 8)
        Text("Settings.")
          .font(.bzrDetailH1)
          .foregroundStyle(Color.txtPrimary)
        Text("Cooldown, tier overrides, remote URL, advisory feed. Use ⌘, for the standalone macOS Settings scene.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 560, alignment: .leading)
        SettingsRoot()
          .frame(maxWidth: 600, alignment: .leading)
          .padding(.top, 12)
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.settings")
  }
}
