// Sojourn — app-icon variant SwiftUI views
//
// Seven render modes mirroring the Claude Design handoff bundle
// (`/sojourn/project/app-icon.jsx`):
//
//   • SojournAppIconLight       — lime gradient squircle, void mark
//   • SojournAppIconDark        — dark slate squircle, lime mark with bloom
//   • SojournAppIconTinted      — monochrome lime mark on dark substrate
//   • SojournAppIconLiquidGlass — depth-stack: substrate → refraction → mark → specular → bevel
//   • SojournAppIconClear       — glass-only, no tint
//   • SojournMenuBarIconView    — 22 pt template image (currentColor-driven)
//   • SojournMenuBarIcon16View  — compact 16 pt variant
//
// All views accept a `size` and render at any scale because every path
// is on a 1024-grid (or 22/16-grid for menu-bar variants). Scale via
// `.frame(width: size, height: size)` and SwiftUI handles aspect.
//
// Stage 1 of `~/.claude/plans/analyze-all-docs-and-mossy-pearl.md` will
// migrate the inline lime color literal to `Color.bzrLime` from the
// design tokens.

import SwiftUI

private let bzrLime = Color.bzrLime

// MARK: - Light mode (default)

internal struct SojournAppIconLight: View {
  var size: CGFloat = 256

  var body: some View {
    let stroke = SojournIconGeometry.markFrameStrokeWidth * size / 1024

    ZStack {
      SojournSquircleShape()
        .fill(
          LinearGradient(
            stops: [
              .init(color: Color(red: 224 / 255, green: 255 / 255, blue: 107 / 255), location: 0),
              .init(color: Color(red: 168 / 255, green: 224 / 255, blue: 0 / 255), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )

      SojournSquircleShape()
        .fill(
          RadialGradient(
            colors: [Color.black.opacity(0.18), Color.black.opacity(0)],
            center: UnitPoint(x: 0.5, y: 0.879),
            startRadius: 0,
            endRadius: 0.508 * size
          )
        )
        .opacity(0.6)

      ShineLayer(opacity: 0.40)

      ZStack {
        SojournIconFrameShape()
          .stroke(Color(red: 14 / 255, green: 14 / 255, blue: 14 / 255), lineWidth: stroke)
        SojournIconMarkShape()
          .fill(Color(red: 14 / 255, green: 14 / 255, blue: 14 / 255), style: FillStyle(eoFill: true))
      }

      SojournSquircleShape()
        .stroke(Color.black.opacity(0.16), lineWidth: 2 * size / 1024)
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Dark mode

internal struct SojournAppIconDark: View {
  var size: CGFloat = 256

  var body: some View {
    let stroke = SojournIconGeometry.markFrameStrokeWidth * size / 1024

    ZStack {
      SojournSquircleShape()
        .fill(
          LinearGradient(
            stops: [
              .init(color: Color(red: 42 / 255, green: 42 / 255, blue: 44 / 255), location: 0),
              .init(color: Color(red: 14 / 255, green: 14 / 255, blue: 14 / 255), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )

      ShineLayer(opacity: 0.10)

      // Lime mark with subtle bloom
      ZStack {
        SojournIconFrameShape().stroke(bzrLime, lineWidth: stroke)
        SojournIconMarkShape().fill(bzrLime, style: FillStyle(eoFill: true))
      }
      .blur(radius: 6 * size / 1024)
      .opacity(0.5)

      ZStack {
        SojournIconFrameShape().stroke(bzrLime, lineWidth: stroke)
        SojournIconMarkShape().fill(bzrLime, style: FillStyle(eoFill: true))
      }

      SojournSquircleShape()
        .stroke(Color.white.opacity(0.06), lineWidth: 2 * size / 1024)
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Tinted mode (system accent applied at runtime)

internal struct SojournAppIconTinted: View {
  var size: CGFloat = 256
  var tint: Color = bzrLime

  var body: some View {
    let stroke = SojournIconGeometry.markFrameStrokeWidth * size / 1024

    ZStack {
      SojournSquircleShape()
        .fill(
          LinearGradient(
            colors: [Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255), Color.black],
            startPoint: .top,
            endPoint: .bottom
          )
        )

      ZStack {
        SojournIconFrameShape().stroke(tint, lineWidth: stroke)
        SojournIconMarkShape().fill(tint, style: FillStyle(eoFill: true))
      }

      SojournSquircleShape()
        .stroke(Color.white.opacity(0.08), lineWidth: 2 * size / 1024)
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Liquid Glass (macOS Tahoe)

internal struct SojournAppIconLiquidGlass: View {
  var size: CGFloat = 256
  var darkWallpaper: Bool = false

  var body: some View {
    let stroke = SojournIconGeometry.markFrameStrokeWidth * size / 1024

    ZStack {
      // Substrate
      SojournSquircleShape()
        .fill(
          LinearGradient(
            colors: darkWallpaper
              ? [Color.white.opacity(0.12), Color.white.opacity(0.04)]
              : [Color.white.opacity(0.65), Color.white.opacity(0.30)],
            startPoint: .top,
            endPoint: .bottom
          )
        )

      // Mark — refracted (offset shadow + lime fill)
      ZStack {
        Group {
          SojournIconFrameShape()
            .stroke(darkWallpaper ? Color.black : Color(red: 14 / 255, green: 14 / 255, blue: 14 / 255), lineWidth: stroke)
          SojournIconMarkShape()
            .fill(
              darkWallpaper ? Color.black : Color(red: 14 / 255, green: 14 / 255, blue: 14 / 255),
              style: FillStyle(eoFill: true)
            )
        }
        .opacity(0.35)
        .offset(x: 8 * size / 1024, y: 12 * size / 1024)

        ZStack {
          SojournIconFrameShape()
            .stroke(
              LinearGradient(
                colors: [bzrLime.opacity(0.65), bzrLime.opacity(0.35)],
                startPoint: .top, endPoint: .bottom
              ),
              lineWidth: stroke
            )
          SojournIconMarkShape()
            .fill(
              LinearGradient(
                colors: [bzrLime.opacity(0.65), bzrLime.opacity(0.35)],
                startPoint: .top, endPoint: .bottom
              ),
              style: FillStyle(eoFill: true)
            )
        }
      }
      .clipShape(SojournSquircleShape())

      // Specular highlight
      SojournSquircleShape()
        .fill(
          RadialGradient(
            stops: [
              .init(color: Color.white.opacity(0.85), location: 0),
              .init(color: Color.white.opacity(0.15), location: 0.4),
              .init(color: Color.white.opacity(0), location: 1)
            ],
            center: UnitPoint(x: 320 / 1024, y: 220 / 1024),
            startRadius: 0,
            endRadius: 400 * size / 1024
          )
        )
        .opacity(0.85)

      // Edge bevel
      SojournSquircleShape()
        .fill(
          LinearGradient(
            stops: [
              .init(color: Color.white.opacity(darkWallpaper ? 0.25 : 0.85), location: 0),
              .init(color: Color.white.opacity(0), location: 0.04),
              .init(color: Color.white.opacity(0), location: 0.96),
              .init(color: Color.black.opacity(darkWallpaper ? 0.45 : 0.15), location: 1)
            ],
            startPoint: .top, endPoint: .bottom
          )
        )

      SojournSquircleShape()
        .stroke(
          darkWallpaper ? Color.white.opacity(0.16) : Color.black.opacity(0.18),
          lineWidth: 2 * size / 1024
        )
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Clear (glass-only, no lime)

internal struct SojournAppIconClear: View {
  var size: CGFloat = 256
  var darkWallpaper: Bool = false

  var body: some View {
    let stroke = SojournIconGeometry.markFrameStrokeWidth * size / 1024

    ZStack {
      SojournSquircleShape()
        .fill(
          LinearGradient(
            colors: darkWallpaper
              ? [Color.white.opacity(0.10), Color.white.opacity(0.04)]
              : [Color.white.opacity(0.55), Color.white.opacity(0.20)],
            startPoint: .top, endPoint: .bottom
          )
        )

      ZStack {
        SojournIconFrameShape()
          .stroke(
            darkWallpaper ? Color.white.opacity(0.85) : Color.black.opacity(0.55),
            lineWidth: stroke
          )
        SojournIconMarkShape()
          .fill(
            darkWallpaper ? Color.white.opacity(0.85) : Color.black.opacity(0.55),
            style: FillStyle(eoFill: true)
          )
      }

      SojournSquircleShape()
        .fill(
          RadialGradient(
            colors: [Color.white.opacity(0.7), Color.white.opacity(0)],
            center: UnitPoint(x: 320 / 1024, y: 220 / 1024),
            startRadius: 0,
            endRadius: 400 * size / 1024
          )
        )
        .opacity(0.85)

      SojournSquircleShape()
        .stroke(
          darkWallpaper ? Color.white.opacity(0.20) : Color.black.opacity(0.20),
          lineWidth: 2 * size / 1024
        )
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Menu-bar template (22 pt)

internal struct SojournMenuBarIconView: View {
  var size: CGFloat = 22
  var color: Color = .primary

  var body: some View {
    ZStack {
      SojournMenuBarFrame22Shape()
        .stroke(color, lineWidth: 1.4 * size / 22)
      SojournMenuBarMark22Shape()
        .fill(color, style: FillStyle(eoFill: true))
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Menu-bar template (16 pt compact)

internal struct SojournMenuBarIcon16View: View {
  var size: CGFloat = 16
  var color: Color = .primary

  var body: some View {
    ZStack {
      SojournMenuBarFrame16Shape()
        .stroke(color, lineWidth: 1.2 * size / 16)
      SojournMenuBarMark16Shape()
        .fill(color, style: FillStyle(eoFill: true))
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Top-of-squircle shine helper

private struct ShineLayer: View {
  var opacity: Double

  var body: some View {
    GeometryReader { geo in
      SojournSquircleShape()
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(opacity), Color.white.opacity(0)],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.371)
          )
        )
        .mask(
          Rectangle()
            .frame(height: geo.size.height * 0.371)
            .frame(maxHeight: .infinity, alignment: .top)
        )
    }
  }
}
