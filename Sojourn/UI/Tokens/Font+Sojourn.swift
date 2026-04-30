// Sojourn — typography tokens.
//
// Type families lifted from `styles.css:76-90` of the Claude Design
// handoff. Variable fonts ship under `Sojourn/Resources/Fonts/`; the
// PostScript family names registered with the system match the CSS
// `font-family` strings.
//
// Stage 1 of the plan registers fonts via `ATSApplicationFontsPath`
// in `Sojourn/Info.plist`; if a name fails to resolve at runtime,
// SwiftUI falls back to system fonts via `Font.custom(_:size:)` —
// never crashes.

import SwiftUI

internal enum BzrFontName {
  static let display  = "Unbounded"
  static let stencil  = "BigShouldersStencil"
  static let body     = "HankenGrotesk"
  static let mono     = "JetBrainsMono"
}

extension Font {
  // MARK: - Family helpers
  static func bzrDisplay(size: CGFloat, weight: Font.Weight = .bold) -> Font {
    .custom(BzrFontName.display, size: size).weight(weight)
  }
  static func bzrStencil(size: CGFloat, weight: Font.Weight = .heavy) -> Font {
    .custom(BzrFontName.stencil, size: size).weight(weight)
  }
  static func bzrBody(size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
    .custom(BzrFontName.body, size: size).weight(weight)
  }
  static func bzrMono(size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
    .custom(BzrFontName.mono, size: size).weight(weight)
  }

  // MARK: - Ramp matching styles.css
  /// 38pt stencil heavy — `h1.detail-h1`.
  static let bzrDetailH1 = Font.bzrStencil(size: 38, weight: .heavy)
  /// 18pt body bold — `h2.detail-h2`.
  static let bzrDetailH2 = Font.bzrBody(size: 18, weight: .bold)
  /// 16pt stencil heavy — `.section-head h3`.
  static let bzrSectionHead = Font.bzrStencil(size: 16, weight: .heavy)
  /// 13pt body — default body.
  static let bzrBodyDefault = Font.bzrBody(size: 13)
  /// 12pt body 600 — buttons and toolbar titles.
  static let bzrButton = Font.bzrBody(size: 12, weight: .semibold)
  /// 11pt mono — code, inline mono.
  static let bzrCode = Font.bzrMono(size: 11)
  /// 10pt mono uppercase — eyebrow + section headers (apply `.tracking()` separately).
  static let bzrEyebrow = Font.bzrMono(size: 10, weight: .semibold)
  /// 9pt mono — tiny eyebrows on cards / table headers.
  static let bzrTinyEyebrow = Font.bzrMono(size: 9, weight: .semibold)
}

extension Text {
  /// Apply standard eyebrow styling: mono 10pt, ~0.18em tracking, uppercase.
  func bzrEyebrowStyle() -> some View {
    self
      .font(.bzrEyebrow)
      .tracking(1.8)
      .textCase(.uppercase)
      .foregroundStyle(Color.txtTertiary)
  }
}
