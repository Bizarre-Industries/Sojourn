// Sojourn — brand and Liquid Glass color tokens.
//
// Adaptive light + dark. Same token names; bodies switch via
// NSColor(name:dynamicProvider:) so the UI reads correctly in both
// macOS appearances.
//
// Dark values match docs/design/handoff/extracted/sojourn/project/styles.css
// verbatim (Claude Design handoff, dark-only spec).
// Light values are designed to keep the same hierarchy: paper-warm
// surfaces, dark labels, lime as accent only (lime-ink = #5E7A00 for
// any "lime body text" — chat2.md design intent).

import AppKit
import SwiftUI

internal func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
  Color(
    nsColor: NSColor(name: nil) { appearance in
      switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
      case .darkAqua: return dark
      default:        return light
      }
    }
  )
}

private func srgb(_ r: Int, _ g: Int, _ b: Int, _ a: Double = 1.0) -> NSColor {
  NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a))
}

extension Color {
  // MARK: - Bizarre brand (fixed across appearances — logo + accent)
  static let bzrLime      = Color(red: 198 / 255, green: 255 / 255, blue: 36 / 255)
  static let bzrLimeInk   = Color(red: 94 / 255, green: 122 / 255, blue: 0 / 255)
  static let bzrLimeGlow  = Color(red: 232 / 255, green: 255 / 255, blue: 138 / 255)
  static let bzrVoid      = Color(red: 14 / 255, green: 14 / 255, blue: 14 / 255)
  static let bzrVoid2     = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255)
  static let bzrVoid3     = Color(red: 43 / 255, green: 43 / 255, blue: 43 / 255)
  static let bzrVoid4     = Color(red: 61 / 255, green: 61 / 255, blue: 61 / 255)
  static let bzrAsh700    = Color(red: 84 / 255, green: 84 / 255, blue: 84 / 255)
  static let bzrAsh500    = Color(red: 122 / 255, green: 122 / 255, blue: 122 / 255)
  static let bzrAsh300    = Color(red: 184 / 255, green: 184 / 255, blue: 184 / 255)
  static let bzrAsh100    = Color(red: 228 / 255, green: 228 / 255, blue: 228 / 255)
  static let bzrPaper     = Color(red: 249 / 255, green: 248 / 255, blue: 242 / 255)
  static let bzrBone      = Color(red: 245 / 255, green: 242 / 255, blue: 234 / 255)
  static let bzrSnow      = Color.white
  static let bzrSuccess   = Color(red: 63 / 255, green: 185 / 255, blue: 80 / 255)
  static let bzrWarn      = Color(red: 232 / 255, green: 163 / 255, blue: 61 / 255)
  static let bzrDanger    = Color(red: 240 / 255, green: 82 / 255, blue: 91 / 255)
  static let bzrInfo      = Color(red: 91 / 255, green: 159 / 255, blue: 255 / 255)

  /// Lime appearance-aware — bright lime in dark, dark lime-ink in light.
  /// Use for "lime body text" so it's readable on both backgrounds.
  static let bzrLimeText  = adaptiveColor(
    light: srgb(94, 122, 0),     // bzr-lime-ink, readable on paper
    dark:  srgb(198, 255, 36)    // bzr-lime
  )

  // MARK: - Liquid Glass surfaces (adaptive translucent overlays)
  static let glassWindow = adaptiveColor(
    light: srgb(249, 248, 242, 0.62),
    dark:  srgb(28, 28, 30, 0.62)
  )
  static let glassSidebar = adaptiveColor(
    light: srgb(245, 242, 234, 0.68),
    dark:  srgb(20, 20, 22, 0.58)
  )
  static let glassToolbar = adaptiveColor(
    light: srgb(255, 255, 255, 0.55),
    dark:  srgb(38, 38, 42, 0.55)
  )
  static let glassContent = adaptiveColor(
    light: srgb(255, 255, 255, 0.50),
    dark:  srgb(40, 40, 44, 0.40)
  )
  static let glassCard = adaptiveColor(
    light: srgb(255, 255, 255, 0.65),
    dark:  srgb(58, 58, 62, 0.42)
  )
  static let glassCardElev = adaptiveColor(
    light: srgb(255, 255, 255, 0.82),
    dark:  srgb(72, 72, 78, 0.55)
  )
  static let glassPopover = adaptiveColor(
    light: srgb(255, 255, 255, 0.88),
    dark:  srgb(48, 48, 52, 0.78)
  )

  // MARK: - Hairlines (adaptive — flips contrast direction)
  static let hairline = adaptiveColor(
    light: NSColor.black.withAlphaComponent(0.12),
    dark:  NSColor.white.withAlphaComponent(0.08)
  )
  static let hairlineStrong = adaptiveColor(
    light: NSColor.black.withAlphaComponent(0.20),
    dark:  NSColor.white.withAlphaComponent(0.14)
  )
  static let hairlineInner = adaptiveColor(
    light: NSColor.black.withAlphaComponent(0.06),
    dark:  NSColor.white.withAlphaComponent(0.06)
  )
  static let hairlineBottom = adaptiveColor(
    light: NSColor.black.withAlphaComponent(0.10),
    dark:  NSColor.black.withAlphaComponent(0.30)
  )

  // MARK: - Text on glass — semantic AppKit labels auto-adapt
  static let txtPrimary    = Color(nsColor: .labelColor)
  static let txtSecondary  = Color(nsColor: .secondaryLabelColor)
  static let txtTertiary   = Color(nsColor: .tertiaryLabelColor)
  static let txtQuaternary = Color(nsColor: .quaternaryLabelColor)

  // MARK: - Sidebar selection (lime accent, slightly stronger in light)
  static let sidebarSel = adaptiveColor(
    light: NSColor(srgbRed: 198 / 255, green: 255 / 255, blue: 36 / 255, alpha: 0.32),
    dark:  NSColor(srgbRed: 198 / 255, green: 255 / 255, blue: 36 / 255, alpha: 0.22)
  )
  static let sidebarSelBord = adaptiveColor(
    light: NSColor(srgbRed: 198 / 255, green: 255 / 255, blue: 36 / 255, alpha: 0.55),
    dark:  NSColor(srgbRed: 198 / 255, green: 255 / 255, blue: 36 / 255, alpha: 0.40)
  )

  // MARK: - Adaptive overlay helpers (used inside primitives)
  static func adaptiveLighten(_ alpha: Double) -> Color {
    adaptiveColor(
      light: NSColor.black.withAlphaComponent(CGFloat(alpha)),
      dark:  NSColor.white.withAlphaComponent(CGFloat(alpha))
    )
  }

  static func adaptiveDeepen(_ alpha: Double) -> Color {
    adaptiveColor(
      light: NSColor.black.withAlphaComponent(CGFloat(alpha * 0.4)),
      dark:  NSColor.black.withAlphaComponent(CGFloat(alpha))
    )
  }
}
