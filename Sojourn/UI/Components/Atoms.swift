// Sojourn — small reusable atoms.
//
// Translations of the recurring patterns in `styles.css` and the JSX
// screens (`carry.jsx`, `screens.jsx`, `extras.jsx`, `power*.jsx`).
// Every pane downstream composes from this set.

import SwiftUI

// MARK: - Eyebrow label (✦ + uppercase mono)

internal struct EyebrowLabel: View {
  let text: String

  var body: some View {
    HStack(spacing: 8) {
      Text("✦")
        .font(.bzrMono(size: 11))
        .foregroundStyle(Color.bzrLime)
      Text(text)
        .font(.bzrEyebrow)
        .tracking(1.8)
        .textCase(.uppercase)
        .foregroundStyle(Color.txtTertiary)
    }
  }
}

// MARK: - Stat strip

internal enum StatKind {
  case neutral, lime, warn, danger
  var color: Color {
    switch self {
    case .neutral: return .txtPrimary
    case .lime:    return .bzrLime
    case .warn:    return .bzrWarn
    case .danger:  return .bzrDanger
    }
  }
}

internal struct Stat: Identifiable {
  let id = UUID()
  let label: String
  let value: String
  let unit: String?
  let kind: StatKind
  let meta: String?
  init(label: String, value: String, unit: String? = nil, kind: StatKind = .neutral, meta: String? = nil) {
    self.label = label; self.value = value; self.unit = unit; self.kind = kind; self.meta = meta
  }
}

internal struct StatStrip: View {
  let stats: [Stat]

  var body: some View {
    HStack(spacing: 0.5) {
      ForEach(stats) { s in
        VStack(alignment: .leading, spacing: 4) {
          Text(s.label)
            .font(.bzrTinyEyebrow)
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(Color.txtTertiary)
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(s.value)
              .font(.bzrStencil(size: 28, weight: .heavy))
              .foregroundStyle(s.kind.color)
            if let unit = s.unit {
              Text(unit)
                .font(.bzrMono(size: 10, weight: .medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Color.txtTertiary)
            }
          }
          if let meta = s.meta {
            Text(meta)
              .font(.bzrMono(size: 10))
              .foregroundStyle(Color.txtTertiary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.glassCard)
      }
    }
    .background(Color.hairline)
    .clipShape(RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .stroke(Color.hairlineStrong, lineWidth: 0.5)
    )
  }
}

// MARK: - Bizarre badge (sharp 2pt corners)

internal enum BzrBadgeKind {
  case tierA, tierB, tierC, tierD, tierE
  case lime, mute, success, warn, danger

  var bg: Color {
    switch self {
    case .tierA, .success: return Color.bzrSuccess.opacity(0.16)
    case .tierB:           return Color.bzrInfo.opacity(0.16)
    case .tierC:           return Color.bzrWarn.opacity(0.16)
    case .tierD, .warn:    return Color.bzrWarn.opacity(0.20)
    case .tierE, .danger:  return Color.bzrDanger.opacity(0.20)
    case .lime:            return Color.bzrLime.opacity(0.18)
    case .mute:            return Color.white.opacity(0.06)
    }
  }
  var fg: Color {
    switch self {
    case .tierA, .success: return Color(red: 108 / 255, green: 230 / 255, blue: 124 / 255)
    case .tierB:           return Color(red: 138 / 255, green: 184 / 255, blue: 255 / 255)
    case .tierC:           return Color(red: 255 / 255, green: 192 / 255, blue: 106 / 255)
    case .tierD, .warn:    return Color(red: 255 / 255, green: 184 / 255, blue: 74 / 255)
    case .tierE, .danger:  return Color(red: 255 / 255, green: 138 / 255, blue: 144 / 255)
    case .lime:            return Color.bzrLime
    case .mute:            return Color.txtSecondary
    }
  }
}

internal struct BzrBadge: View {
  let text: String
  let kind: BzrBadgeKind

  var body: some View {
    Text(text)
      .font(.bzrTinyEyebrow)
      .tracking(1.4)
      .textCase(.uppercase)
      .foregroundStyle(kind.fg)
      .padding(.horizontal, 7)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
          .fill(kind.bg)
          .overlay(
            RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
              .stroke(kind.fg.opacity(0.30), lineWidth: 0.5)
          )
      )
  }
}

// MARK: - Callout (lime/warn/danger info box)

internal enum BzrCalloutKind {
  case info, warn, danger
  var bg: Color {
    switch self {
    case .info:   return Color.bzrLime.opacity(0.06)
    case .warn:   return Color.bzrWarn.opacity(0.08)
    case .danger: return Color.bzrDanger.opacity(0.10)
    }
  }
  var stroke: Color {
    switch self {
    case .info:   return Color.bzrLime.opacity(0.25)
    case .warn:   return Color.bzrWarn.opacity(0.30)
    case .danger: return Color.bzrDanger.opacity(0.35)
    }
  }
  var markBg: Color {
    switch self {
    case .info:   return Color.bzrLime
    case .warn:   return Color.bzrWarn
    case .danger: return Color.bzrDanger
    }
  }
  var markFg: Color {
    switch self {
    case .info, .warn: return Color.bzrVoid
    case .danger:      return Color.white
    }
  }
  var titleColor: Color {
    switch self {
    case .info:   return Color.bzrLime
    case .warn:   return Color(red: 255 / 255, green: 184 / 255, blue: 74 / 255)
    case .danger: return Color(red: 255 / 255, green: 138 / 255, blue: 144 / 255)
    }
  }
}

internal struct BzrCallout: View {
  let title: String
  let kind: BzrCalloutKind
  let bodyText: String
  var mark: String = "★"

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Text(mark)
        .font(.bzrStencil(size: 13, weight: .heavy))
        .foregroundStyle(kind.markFg)
        .frame(width: 22, height: 22)
        .background(
          RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(kind.markBg)
        )

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.bzrEyebrow)
          .tracking(1.8)
          .textCase(.uppercase)
          .foregroundStyle(kind.titleColor)
        Text(bodyText)
          .font(.bzrBodyDefault)
          .foregroundStyle(Color.txtPrimary)
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(kind.bg)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(kind.stroke, lineWidth: 0.5)
        )
    )
  }
}

// MARK: - Generic glass card

internal struct BzrCard<Content: View>: View {
  let title: String?
  let eyebrow: String?
  let content: Content

  init(title: String? = nil, eyebrow: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.eyebrow = eyebrow
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if eyebrow != nil || title != nil {
        VStack(alignment: .leading, spacing: 2) {
          if let e = eyebrow {
            Text(e)
              .font(.bzrTinyEyebrow)
              .tracking(1.6)
              .textCase(.uppercase)
              .foregroundStyle(Color.txtTertiary)
          }
          if let t = title {
            Text(t)
              .font(.bzrBody(size: 13, weight: .bold))
              .foregroundStyle(Color.txtPrimary)
          }
        }
      }
      content
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
        .fill(Color.glassCard)
        .overlay(
          RoundedRectangle(cornerRadius: BzrRadius.card, style: .continuous)
            .stroke(Color.hairlineStrong, lineWidth: 0.5)
        )
    )
  }
}

// MARK: - Code block

internal struct BzrCodeBlock: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.bzrCode)
      .foregroundStyle(Color.txtSecondary)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
          .fill(Color.black.opacity(0.40))
          .overlay(
            RoundedRectangle(cornerRadius: BzrRadius.bzrSharp, style: .continuous)
              .stroke(Color.hairline, lineWidth: 0.5)
          )
      )
  }
}

// MARK: - Status dot

internal enum StatusDotKind {
  case ok, warn, danger, lime
  var color: Color {
    switch self {
    case .ok:     return .bzrSuccess
    case .warn:   return .bzrWarn
    case .danger: return .bzrDanger
    case .lime:   return .bzrLime
    }
  }
}

internal struct StatusDot: View {
  let kind: StatusDotKind

  var body: some View {
    Circle()
      .fill(kind.color)
      .frame(width: 6, height: 6)
      .shadow(color: kind.color.opacity(0.7), radius: 3)
  }
}

// MARK: - Progress bar (lime)

internal struct BzrProgressBar: View {
  /// 0...1
  let value: Double

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.white.opacity(0.08))
        Capsule()
          .fill(Color.bzrLime)
          .shadow(color: Color.bzrLime.opacity(0.50), radius: 4)
          .frame(width: max(0, min(1, value)) * geo.size.width)
      }
    }
    .frame(height: 4)
  }
}

// MARK: - Toggle (macOS-style, lime on)

internal struct BzrToggle: View {
  @Binding var isOn: Bool

  var body: some View {
    Button {
      isOn.toggle()
    } label: {
      ZStack(alignment: isOn ? .trailing : .leading) {
        Capsule()
          .fill(isOn ? Color.bzrLime : Color.white.opacity(0.10))
          .overlay(Capsule().stroke(Color.hairline, lineWidth: 0.5))
          .shadow(color: isOn ? Color.bzrLime.opacity(0.40) : .clear, radius: 6)
        Circle()
          .fill(Color.white)
          .frame(width: 15, height: 15)
          .shadow(color: Color.black.opacity(0.4), radius: 1, y: 1)
          .padding(2)
      }
      .frame(width: 32, height: 19)
      .animation(.easeInOut(duration: 0.2), value: isOn)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Active-machine footer card

internal struct MachineFooterCard: View {
  let name: String
  let role: String
  let lastActivity: String
  let sha: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        StatusDot(kind: .lime)
        Text(name)
          .font(.bzrBody(size: 12, weight: .semibold))
          .foregroundStyle(Color.txtPrimary)
      }
      Text("\(role) · \(lastActivity)")
        .font(.bzrMono(size: 10))
        .tracking(0.4)
        .foregroundStyle(Color.txtTertiary)
      if let sha {
        Text("↑ \(sha)")
          .font(.bzrMono(size: 10))
          .foregroundStyle(Color.bzrLime.opacity(0.65))
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.white.opacity(0.04))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Color.hairline, lineWidth: 0.5)
        )
    )
  }
}
