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

/// Honest empty-state for a pane that has no live data source wired yet.
/// Used in place of fake demo data: shows the pane's eyebrow + title + a
/// short paragraph describing what will populate the surface once its
/// underlying service is wired.
struct PaneEmptyState: View {
  let eyebrow: String
  let title: String
  let subtitle: String

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        EyebrowLabel(text: eyebrow)
        Text(title)
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text(subtitle)
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)
        Spacer(minLength: 0)
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
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
