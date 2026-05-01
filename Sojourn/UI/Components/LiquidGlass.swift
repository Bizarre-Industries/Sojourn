// Sojourn — Liquid Glass primitives.
//
// SwiftUI translation of `liquid-glass.css` from the Claude Design handoff:
// authentic macOS Tahoe / Sequoia material treatment over the Bizarre brand.
// The window, sidebar, toolbar, sheet, popover, and control surfaces all
// use system materials for live blur + saturation, plus a Bizarre tint.

import SwiftUI

// MARK: - Window background

internal struct LiquidGlassBackground: ViewModifier {
  var tint: Color = .glassWindow
  var cornerRadius: CGFloat = BzrRadius.window

  func body(content: Content) -> some View {
    content
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tint)
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        }
      )
  }
}

extension View {
  func liquidGlass(tint: Color = .glassWindow, cornerRadius: CGFloat = BzrRadius.window) -> some View {
    modifier(LiquidGlassBackground(tint: tint, cornerRadius: cornerRadius))
  }
}

// MARK: - Wallpaper layer

/// Authentic Tahoe aurora wallpaper. Translation of `liquid-glass.css:8-40`
/// — the high-saturation, photographic-grain layer that Liquid Glass
/// surfaces refract above. Five radial color blooms (lime / pink / amber /
/// blue / purple) over a deep void gradient, with star-dust speckle.
///
/// Use as the deepest layer of the window. The Liquid Glass material on
/// the sidebar / content tiles needs *something* saturated to refract;
/// a flat dark fill produces fog, not glass.
internal struct GlassWallpaper: View {
  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      ZStack {
        // Base diagonal gradient.
        LinearGradient(
          gradient: Gradient(colors: [
            Color(red: 10 / 255, green: 10 / 255, blue: 20 / 255),
            Color(red: 26 / 255, green: 14 / 255, blue: 31 / 255)
          ]),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        // Aurora blooms — sized to the viewport so the refraction holds
        // at every window dimension.
        bloom(color: Color.bzrLime, x: 0.12 * w, y: 0.18 * h, r: 0.55 * max(w, h))
        bloom(color: Color(red: 255 / 255, green: 91 / 255, blue: 138 / 255), x: 0.88 * w, y: 0.82 * h, r: 0.65 * max(w, h))
        bloom(color: Color(red: 255 / 255, green: 209 / 255, blue: 102 / 255), x: 0.78 * w, y: 0.18 * h, r: 0.55 * max(w, h))
        bloom(color: Color.bzrInfo, x: 0.22 * w, y: 0.78 * h, r: 0.60 * max(w, h))
        bloom(color: Color(red: 138 / 255, green: 61 / 255, blue: 255 / 255), x: 0.50 * w, y: 0.50 * h, r: 0.50 * max(w, h))

        // Star-dust speckle. Twelve fixed offsets — deterministic so the
        // wallpaper doesn't flicker between renders.
        ForEach(Self.stardust, id: \.self) { dot in
          Circle()
            .fill(Color.white.opacity(dot.opacity))
            .frame(width: dot.size, height: dot.size)
            .offset(x: dot.x * w - w / 2, y: dot.y * h - h / 2)
        }
      }
      .saturation(1.10)
    }
    .ignoresSafeArea()
  }

  private func bloom(color: Color, x: CGFloat, y: CGFloat, r: CGFloat) -> some View {
    Circle()
      .fill(color)
      .frame(width: r * 1.6, height: r * 1.2)
      .blur(radius: r * 0.45)
      .offset(x: x - r * 0.8, y: y - r * 0.6)
      .blendMode(.plusLighter)
      .opacity(0.55)
  }

  private struct Speck: Hashable {
    let x: Double; let y: Double
    let size: CGFloat; let opacity: Double
  }

  private static let stardust: [Speck] = [
    Speck(x: 0.12, y: 0.18, size: 2.0, opacity: 0.85),
    Speck(x: 0.28, y: 0.67, size: 1.5, opacity: 0.70),
    Speck(x: 0.71, y: 0.44, size: 1.5, opacity: 0.75),
    Speck(x: 0.86, y: 0.81, size: 2.0, opacity: 0.85),
    Speck(x: 0.92, y: 0.23, size: 1.0, opacity: 0.60),
    Speck(x: 0.36, y: 0.89, size: 1.0, opacity: 0.50),
    Speck(x: 0.54, y: 0.12, size: 1.5, opacity: 0.70),
    Speck(x: 0.08, y: 0.56, size: 1.5, opacity: 0.65),
    Speck(x: 0.62, y: 0.32, size: 1.0, opacity: 0.55),
    Speck(x: 0.18, y: 0.42, size: 1.0, opacity: 0.45),
    Speck(x: 0.74, y: 0.71, size: 1.5, opacity: 0.65),
    Speck(x: 0.46, y: 0.58, size: 1.0, opacity: 0.50)
  ]
}

// MARK: - Glass buttons

internal struct GlassCapsuleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.bzrButton)
      .foregroundStyle(Color.txtPrimary)
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .background(
        Capsule()
          .fill(Color.white.opacity(configuration.isPressed ? 0.20 : 0.10))
          .overlay(Capsule().stroke(Color.hairlineStrong, lineWidth: 0.5))
      )
      .contentShape(Capsule())
  }
}

internal struct GlassPrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.bzrButton)
      .foregroundStyle(Color.bzrVoid)
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .background(
        Capsule()
          .fill(configuration.isPressed ? Color.bzrLimeGlow : Color.bzrLime)
          .shadow(color: Color.bzrLime.opacity(0.30), radius: 9)
      )
      .contentShape(Capsule())
  }
}

internal struct GlassDangerButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.bzrButton)
      .foregroundStyle(Color(red: 255 / 255, green: 138 / 255, blue: 144 / 255))
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .background(
        Capsule()
          .fill(Color.bzrDanger.opacity(configuration.isPressed ? 0.30 : 0.20))
          .overlay(Capsule().stroke(Color.bzrDanger.opacity(0.40), lineWidth: 0.5))
      )
      .contentShape(Capsule())
  }
}

internal struct GlassGhostButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.bzrButton)
      .foregroundStyle(configuration.isPressed ? Color.txtPrimary : Color.txtSecondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        Capsule()
          .fill(configuration.isPressed ? Color.white.opacity(0.06) : Color.clear)
      )
      .contentShape(Capsule())
  }
}

// MARK: - Glass segmented control

internal struct GlassSegmentedControl<Selection: Hashable>: View {
  @Binding var selection: Selection
  let options: [(label: String, value: Selection)]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(options.enumerated()), id: \.element.value) { _, option in
        let isActive = option.value == selection
        Button {
          selection = option.value
        } label: {
          Text(option.label)
            .font(.bzrBody(size: 11, weight: .semibold))
            .foregroundStyle(isActive ? Color.txtPrimary : Color.txtSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
              RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isActive ? Color.white.opacity(0.12) : Color.clear)
                .overlay(
                  RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(isActive ? Color.hairlineStrong : Color.clear, lineWidth: 0.5)
                )
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(2)
    .background(
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(Color.black.opacity(0.30))
        .overlay(
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(Color.hairline, lineWidth: 0.5)
        )
    )
  }
}

// MARK: - Sheet host

internal struct GlassSheetBackground: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.regularMaterial)
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(red: 36 / 255, green: 36 / 255, blue: 40 / 255).opacity(0.40))
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        }
      )
      .shadow(color: Color.black.opacity(0.7), radius: 30, x: 0, y: 12)
  }
}
