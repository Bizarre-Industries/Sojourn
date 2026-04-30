// Sojourn — spacing tokens.
//
// Standard 4/8/12/16/24/32 ramp from `styles.css` `.gap-*` helpers,
// plus geometry constants for the chrome (toolbar, sidebar, etc.).

import SwiftUI

internal enum BzrSpacing {
  static let xs:  CGFloat = 4
  static let sm:  CGFloat = 8
  static let md:  CGFloat = 12
  static let lg:  CGFloat = 16
  static let xl:  CGFloat = 24
  static let xxl: CGFloat = 32

  // Chrome geometry — `chrome.jsx` + `styles.css`.
  static let titlebarHeight: CGFloat = 38
  static let toolbarHeight:  CGFloat = 52
  static let sidebarWidth:   CGFloat = 220
  static let midlistWidth:   CGFloat = 280
}
