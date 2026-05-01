// Sojourn — PaneHero & PaneScaffold

import SwiftUI

struct PaneHero: View {
  let eyebrow: String
  let title: String
  let subtitle: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      EyebrowLabel(text: eyebrow)
      Text(title)
        .font(.bzrDetailH1)
        .foregroundStyle(Color.txtPrimary)
        .lineLimit(1)
      if let subtitle {
        Text(subtitle)
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 8, alignment: .leading)
      }
    }
  }
}

struct PaneScaffold<Content: View>: View {
  let hero: PaneHero
  let content: Content

  init(hero: PaneHero, @ViewBuilder content: () -> Content) {
    self.hero = hero
    self.content = content()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        hero
        content
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
