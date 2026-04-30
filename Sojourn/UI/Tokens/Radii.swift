// Sojourn — corner-radius tokens.
//
// Lifted from `styles.css:82-90` of the Claude Design handoff:
//   --r-window:  12px;   /* Apple Tahoe-era window */
//   --r-card:    10px;
//   --r-control: 8px;
//   --r-pill:    999px;  /* SwiftUI: use Capsule() shape */
//   --r-bzr:     2px;    /* sharp Bizarre corners on data tables, badges */

import SwiftUI

internal enum BzrRadius {
  static let window:   CGFloat = 12
  static let card:     CGFloat = 10
  static let control:  CGFloat = 8
  static let bzrSharp: CGFloat = 2
}
