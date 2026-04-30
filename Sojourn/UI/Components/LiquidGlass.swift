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

/// Aurora wallpaper bleeding through the Liquid Glass window. Pulled
/// from `styles.css:107-130`. Use as the deepest layer of any preview
/// or in-situ artboard.
internal struct GlassWallpaper: View {
  var body: some View {
    ZStack {
      Color(red: 10/255, green: 10/255, blue: 14/255)
      Circle()
        .fill(Color(red: 42/255, green: 61/255, blue: 18/255))
        .blur(radius: 200)
        .frame(width: 900, height: 700)
        .offset(x: -240, y: -180)
      Circle()
        .fill(Color(red: 74/255, green: 42/255, blue: 85/255))
        .blur(radius: 240)
        .frame(width: 1100, height: 800)
        .offset(x: 320, y: 280)
      Circle()
        .fill(Color(red: 26/255, green: 51/255, blue: 64/255))
        .blur(radius: 180)
        .frame(width: 700, height: 600)
        .offset(x: 60, y: 0)
    }
    .ignoresSafeArea()
  }
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
      .foregroundStyle(Color(red: 255/255, green: 138/255, blue: 144/255))
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
            .fill(Color(red: 36/255, green: 36/255, blue: 40/255).opacity(0.40))
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        }
      )
      .shadow(color: Color.black.opacity(0.7), radius: 30, x: 0, y: 12)
  }
}
