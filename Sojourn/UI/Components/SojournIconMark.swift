// Sojourn — app-icon mark primitives
//
// Vector path data lifted verbatim from the Claude Design handoff bundle
// (`/sojourn/project/app-icon.jsx`, `Sojourn App Icon.html` — fetched
// 2026-04-30 from `api.anthropic.com/v1/design/h/-V60EHW1lagdK3XrdMPR1g`).
//
// Geometry contract:
//   • The 1024×1024 master grid matches macOS Big Sur / Sequoia / Tahoe.
//   • 100 pt safe-area inset (mark stays inside 100..924).
//   • Square frame at 200..824 (624×624), 36 pt corner radius, 38 pt
//     stroke. Reads at 16 pt dock size.
//   • Stencil S inside the frame with two horizontal cuts at 1/3 and
//     2/3 of the frame height.
//   • Outer squircle uses Apple's continuous-corner approximation
//     (~225 pt radius on the 1024 grid) drawn as cubic Béziers.

import AppKit
import SwiftUI

// MARK: - 1024-grid constants

internal enum SojournIconGeometry {
  static let masterSize: CGFloat = 1024
  static let safeAreaInset: CGFloat = 100
  static let markFrameInset: CGFloat = 200
  static let markFrameSize: CGFloat = 624
  static let markFrameCornerRadius: CGFloat = 36
  static let markFrameStrokeWidth: CGFloat = 38
}

// MARK: - Squircle path
//
// Direct translation of `SQUIRCLE_PATH` from `app-icon.jsx`:
//   M242 0 h540 c133.78 0 242 108.22 242 242 v540 c0 133.78 -108.22 242 -242 242
//   H242 C108.22 1024 0 915.78 0 782 V242 C0 108.22 108.22 0 242 0 z
internal func sojournSquirclePath(in rect: CGRect = CGRect(x: 0, y: 0, width: 1024, height: 1024)) -> Path {
  Path { p in
    let x0 = rect.minX
    let y0 = rect.minY
    let s = rect.width / 1024
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: x0 + x * s, y: y0 + y * s)
    }
    p.move(to: pt(242, 0))
    p.addLine(to: pt(782, 0))
    p.addCurve(to: pt(1024, 242), control1: pt(915.78, 0), control2: pt(1024, 108.22))
    p.addLine(to: pt(1024, 782))
    p.addCurve(to: pt(782, 1024), control1: pt(1024, 915.78), control2: pt(915.78, 1024))
    p.addLine(to: pt(242, 1024))
    p.addCurve(to: pt(0, 782), control1: pt(108.22, 1024), control2: pt(0, 915.78))
    p.addLine(to: pt(0, 242))
    p.addCurve(to: pt(242, 0), control1: pt(0, 108.22), control2: pt(108.22, 0))
    p.closeSubpath()
  }
}

// MARK: - Stencil S body (use with `.eoFill` so the cuts knock through)

internal func sojournIconMarkPath(
  in rect: CGRect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
) -> Path {
  Path { p in
    let x0 = rect.minX
    let y0 = rect.minY
    let s = rect.width / 1024
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: x0 + x * s, y: y0 + y * s)
    }

    // Outer S body
    p.move(to: pt(312, 332))
    p.addLine(to: pt(312, 484))
    p.addLine(to: pt(592, 484))
    p.addLine(to: pt(592, 540))
    p.addLine(to: pt(312, 540))
    p.addLine(to: pt(312, 692))
    p.addLine(to: pt(712, 692))
    p.addLine(to: pt(712, 540))
    p.addLine(to: pt(432, 540))
    p.addLine(to: pt(432, 484))
    p.addLine(to: pt(712, 484))
    p.addLine(to: pt(712, 332))
    p.closeSubpath()

    // Top stencil cut
    p.move(to: pt(340, 360))
    p.addLine(to: pt(684, 360))
    p.addLine(to: pt(684, 412))
    p.addLine(to: pt(340, 412))
    p.closeSubpath()

    // Bottom stencil cut
    p.move(to: pt(340, 564))
    p.addLine(to: pt(684, 564))
    p.addLine(to: pt(684, 616))
    p.addLine(to: pt(340, 616))
    p.closeSubpath()
  }
}

// MARK: - Square frame (round-rect at 200..824)

internal func sojournIconFramePath(
  in rect: CGRect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
) -> Path {
  let s = rect.width / 1024
  let frame = CGRect(
    x: rect.minX + 200 * s,
    y: rect.minY + 200 * s,
    width: 624 * s,
    height: 624 * s
  )
  return Path { p in
    p.addRoundedRect(in: frame, cornerSize: CGSize(width: 36 * s, height: 36 * s))
  }
}

// MARK: - Menu-bar template glyph (22 pt grid)
//
// Direct translation of `SojournMenuBarIcon` in `app-icon.jsx`. Drawn on a
// 22-unit grid; callers scale via the rect.
internal func sojournMenuBarFrame22Path(in rect: CGRect) -> Path {
  let s = rect.width / 22
  let frame = CGRect(
    x: rect.minX + 2.5 * s,
    y: rect.minY + 3.5 * s,
    width: 17 * s,
    height: 15 * s
  )
  return Path { p in
    p.addRoundedRect(in: frame, cornerSize: CGSize(width: 1.5 * s, height: 1.5 * s))
  }
}

internal func sojournMenuBarMark22Path(in rect: CGRect) -> Path {
  Path { p in
    let x0 = rect.minX
    let y0 = rect.minY
    let s = rect.width / 22
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: x0 + x * s, y: y0 + y * s)
    }

    // S body
    p.move(to: pt(5.4, 6.3))
    p.addLine(to: pt(5.4, 10.2))
    p.addLine(to: pt(13.4, 10.2))
    p.addLine(to: pt(13.4, 11.6))
    p.addLine(to: pt(5.4, 11.6))
    p.addLine(to: pt(5.4, 15.7))
    p.addLine(to: pt(16.6, 15.7))
    p.addLine(to: pt(16.6, 11.6))
    p.addLine(to: pt(8.6, 11.6))
    p.addLine(to: pt(8.6, 10.2))
    p.addLine(to: pt(16.6, 10.2))
    p.addLine(to: pt(16.6, 6.3))
    p.closeSubpath()

    // Top stencil cut
    p.move(to: pt(6.2, 7.0))
    p.addLine(to: pt(15.8, 7.0))
    p.addLine(to: pt(15.8, 8.4))
    p.addLine(to: pt(6.2, 8.4))
    p.closeSubpath()

    // Bottom stencil cut
    p.move(to: pt(6.2, 13.4))
    p.addLine(to: pt(15.8, 13.4))
    p.addLine(to: pt(15.8, 14.9))
    p.addLine(to: pt(6.2, 14.9))
    p.closeSubpath()
  }
}

// MARK: - Compact 16-pt menu-bar variant

internal func sojournMenuBarFrame16Path(in rect: CGRect) -> Path {
  let s = rect.width / 16
  let frame = CGRect(
    x: rect.minX + 2 * s,
    y: rect.minY + 2.5 * s,
    width: 12 * s,
    height: 11 * s
  )
  return Path { p in
    p.addRoundedRect(in: frame, cornerSize: CGSize(width: 1 * s, height: 1 * s))
  }
}

internal func sojournMenuBarMark16Path(in rect: CGRect) -> Path {
  Path { p in
    let x0 = rect.minX
    let y0 = rect.minY
    let s = rect.width / 16
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: x0 + x * s, y: y0 + y * s)
    }
    p.move(to: pt(4, 5))
    p.addLine(to: pt(4, 7.5))
    p.addLine(to: pt(10, 7.5))
    p.addLine(to: pt(10, 8.5))
    p.addLine(to: pt(4, 8.5))
    p.addLine(to: pt(4, 11))
    p.addLine(to: pt(12, 11))
    p.addLine(to: pt(12, 8.5))
    p.addLine(to: pt(6, 8.5))
    p.addLine(to: pt(6, 7.5))
    p.addLine(to: pt(12, 7.5))
    p.addLine(to: pt(12, 5))
    p.closeSubpath()
  }
}

// MARK: - NSImage template (for MenuBarExtra label)
//
// SwiftUI's MenuBarExtra(label:) silently converts the label view to an
// NSImage with isTemplate=true. SwiftUI Path-based Shape views don't
// always survive that conversion (the rasterized output can be empty
// or wrongly clipped). This helper draws the menu-bar mark + frame
// directly into an NSImage we mark as template ourselves, then hand
// to AppKit. Result: the menubar shows the actual Sojourn S in a
// rounded square that tints to the menubar foreground (white in dark
// menubar, near-black in light menubar).

internal func sojournMenuBarTemplateImage(size: CGFloat = 18) -> NSImage {
  let pxSize = NSSize(width: size, height: size)
  let img = NSImage(size: pxSize, flipped: false) { rect in
    NSColor.black.setStroke()
    NSColor.black.setFill()

    // Frame: stroke a rounded square. Width matches SwiftUI version
    // (1.4 * size / 22).
    let framePath = NSBezierPath(cgPath: sojournMenuBarFrame22Path(in: rect).cgPath)
    framePath.lineWidth = 1.4 * rect.width / 22
    framePath.stroke()

    // Mark: fill the S body with two stencil cuts knocked through via
    // even-odd winding (matching the SwiftUI .eoFill() behavior).
    let markPath = NSBezierPath(cgPath: sojournMenuBarMark22Path(in: rect).cgPath)
    markPath.windingRule = .evenOdd
    markPath.fill()

    return true
  }
  // The template flag is what makes AppKit re-tint the image to the
  // menubar foreground color in both dark and light menubars.
  img.isTemplate = true
  return img
}

// MARK: - SwiftUI Shapes

/// The S glyph + two stencil cuts. Render with `.eoFill()` so the cuts
/// knock through the body.
internal struct SojournIconMarkShape: Shape {
  func path(in rect: CGRect) -> Path { sojournIconMarkPath(in: rect) }
}

/// The square mark frame. Stroke; don't fill.
internal struct SojournIconFrameShape: Shape {
  func path(in rect: CGRect) -> Path { sojournIconFramePath(in: rect) }
}

/// The outer macOS squircle (1024 grid). Fill or stroke as needed.
internal struct SojournSquircleShape: Shape {
  func path(in rect: CGRect) -> Path { sojournSquirclePath(in: rect) }
}

/// The 22-pt menu-bar template glyph (S body + stencil cuts).
internal struct SojournMenuBarMark22Shape: Shape {
  func path(in rect: CGRect) -> Path { sojournMenuBarMark22Path(in: rect) }
}

internal struct SojournMenuBarFrame22Shape: Shape {
  func path(in rect: CGRect) -> Path { sojournMenuBarFrame22Path(in: rect) }
}

internal struct SojournMenuBarMark16Shape: Shape {
  func path(in rect: CGRect) -> Path { sojournMenuBarMark16Path(in: rect) }
}

internal struct SojournMenuBarFrame16Shape: Shape {
  func path(in rect: CGRect) -> Path { sojournMenuBarFrame16Path(in: rect) }
}
