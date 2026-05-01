// Sojourn — brand and Liquid Glass color tokens.
//
// Lifted verbatim from `styles.css:30-75` of the Claude Design handoff
// (`api.anthropic.com/v1/design/h/Msye6VOHMlrrBwdiZuuo-A`,
// `/sojourn/project/styles.css`). Exact RGBA — no approximation.

import SwiftUI

extension Color {
  // MARK: - Bizarre brand
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

  // MARK: - Liquid Glass surfaces (translucent overlays)
  static let glassWindow   = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255).opacity(0.62)
  static let glassSidebar  = Color(red: 20 / 255, green: 20 / 255, blue: 22 / 255).opacity(0.58)
  static let glassToolbar  = Color(red: 38 / 255, green: 38 / 255, blue: 42 / 255).opacity(0.55)
  static let glassContent  = Color(red: 40 / 255, green: 40 / 255, blue: 44 / 255).opacity(0.40)
  static let glassCard     = Color(red: 58 / 255, green: 58 / 255, blue: 62 / 255).opacity(0.42)
  static let glassCardElev = Color(red: 72 / 255, green: 72 / 255, blue: 78 / 255).opacity(0.55)
  static let glassPopover  = Color(red: 48 / 255, green: 48 / 255, blue: 52 / 255).opacity(0.78)

  // MARK: - Hairlines
  static let hairline        = Color.white.opacity(0.08)
  static let hairlineStrong  = Color.white.opacity(0.14)
  static let hairlineInner   = Color.white.opacity(0.06)
  static let hairlineBottom  = Color.black.opacity(0.30)

  // MARK: - Text on glass
  static let txtPrimary    = Color.white.opacity(0.96)
  static let txtSecondary  = Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.62)
  static let txtTertiary   = Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.40)
  static let txtQuaternary = Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.24)

  // MARK: - Sidebar selection
  static let sidebarSel     = Color.bzrLime.opacity(0.22)
  static let sidebarSelBord = Color.bzrLime.opacity(0.40)
}
