#!/usr/bin/env swift
//
// Sojourn — render the AppIcon set to PNG.
//
// Run from repo root: `swift scripts/render-app-icons.swift`. Writes:
//   Sojourn/Resources/Assets.xcassets/AppIcon.appiconset/{icon,dark,tinted}_*.png
//
// Light is the default. Dark + Tinted appear as appearance variants in
// Contents.json (handled by a sibling Contents.json patch). Liquid Glass
// and Clear are not exported — macOS Tahoe composes the runtime Liquid
// Glass effect over the Light icon, and Clear is showcase-only.
//
// CoreGraphics directly (no SwiftUI) for deterministic bytes. Path data
// lifted from `/sojourn/project/app-icon.jsx` of the Claude Design
// handoff (`api.anthropic.com/v1/design/h/-V60EHW1lagdK3XrdMPR1g`).

import AppKit
import CoreGraphics
import Foundation

// MARK: - 1024 master grid

let masterSize: CGFloat = 1024
let markFrameInset: CGFloat = 200
let markFrameSize: CGFloat = 624
let markFrameCorner: CGFloat = 36
let markFrameStroke: CGFloat = 38

// MARK: - Path builders

func squirclePath() -> CGMutablePath {
  let p = CGMutablePath()
  p.move(to: CGPoint(x: 242, y: 0))
  p.addLine(to: CGPoint(x: 782, y: 0))
  p.addCurve(
    to: CGPoint(x: 1024, y: 242),
    control1: CGPoint(x: 915.78, y: 0),
    control2: CGPoint(x: 1024, y: 108.22)
  )
  p.addLine(to: CGPoint(x: 1024, y: 782))
  p.addCurve(
    to: CGPoint(x: 782, y: 1024),
    control1: CGPoint(x: 1024, y: 915.78),
    control2: CGPoint(x: 915.78, y: 1024)
  )
  p.addLine(to: CGPoint(x: 242, y: 1024))
  p.addCurve(
    to: CGPoint(x: 0, y: 782),
    control1: CGPoint(x: 108.22, y: 1024),
    control2: CGPoint(x: 0, y: 915.78)
  )
  p.addLine(to: CGPoint(x: 0, y: 242))
  p.addCurve(
    to: CGPoint(x: 242, y: 0),
    control1: CGPoint(x: 0, y: 108.22),
    control2: CGPoint(x: 108.22, y: 0)
  )
  p.closeSubpath()
  return p
}

func markPath() -> CGMutablePath {
  let p = CGMutablePath()
  // Outer S body
  p.move(to: CGPoint(x: 312, y: 332))
  p.addLine(to: CGPoint(x: 312, y: 484))
  p.addLine(to: CGPoint(x: 592, y: 484))
  p.addLine(to: CGPoint(x: 592, y: 540))
  p.addLine(to: CGPoint(x: 312, y: 540))
  p.addLine(to: CGPoint(x: 312, y: 692))
  p.addLine(to: CGPoint(x: 712, y: 692))
  p.addLine(to: CGPoint(x: 712, y: 540))
  p.addLine(to: CGPoint(x: 432, y: 540))
  p.addLine(to: CGPoint(x: 432, y: 484))
  p.addLine(to: CGPoint(x: 712, y: 484))
  p.addLine(to: CGPoint(x: 712, y: 332))
  p.closeSubpath()

  // Top stencil cut
  p.move(to: CGPoint(x: 340, y: 360))
  p.addLine(to: CGPoint(x: 684, y: 360))
  p.addLine(to: CGPoint(x: 684, y: 412))
  p.addLine(to: CGPoint(x: 340, y: 412))
  p.closeSubpath()

  // Bottom stencil cut
  p.move(to: CGPoint(x: 340, y: 564))
  p.addLine(to: CGPoint(x: 684, y: 564))
  p.addLine(to: CGPoint(x: 684, y: 616))
  p.addLine(to: CGPoint(x: 340, y: 616))
  p.closeSubpath()
  return p
}

func framePath() -> CGMutablePath {
  let p = CGMutablePath()
  p.addRoundedRect(
    in: CGRect(x: markFrameInset, y: markFrameInset, width: markFrameSize, height: markFrameSize),
    cornerWidth: markFrameCorner,
    cornerHeight: markFrameCorner
  )
  return p
}

// MARK: - Colors

func cgColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
  CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

let voidColor = cgColor(14, 14, 14)
let limeColor = cgColor(198, 255, 36)
let limeTopColor = cgColor(224, 255, 107)
let limeBottomColor = cgColor(168, 224, 0)
let darkSlateTop = cgColor(42, 42, 44)
let darkSlateBottom = cgColor(14, 14, 14)
let tintBgTop = cgColor(26, 26, 28)
let tintBgBottom = cgColor(0, 0, 0)

// MARK: - Variant renderer

enum Variant {
  case light, dark, tinted
}

func render(variant: Variant, size: Int) -> CGImage? {
  let pixels = size
  let cs = CGColorSpaceCreateDeviceRGB()
  guard let ctx = CGContext(
    data: nil,
    width: pixels,
    height: pixels,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { return nil }

  // Flip so SVG-style top-left coordinates render correctly.
  ctx.translateBy(x: 0, y: CGFloat(pixels))
  ctx.scaleBy(x: 1, y: -1)

  let scale = CGFloat(pixels) / masterSize
  ctx.scaleBy(x: scale, y: scale)

  let squircle = squirclePath()

  // Body — clip to squircle, fill with variant gradient + accents.
  ctx.saveGState()
  ctx.addPath(squircle)
  ctx.clip()

  switch variant {
  case .light:
    drawLinearGradient(in: ctx, top: limeTopColor, bottom: limeBottomColor)
    drawBottomShadow(in: ctx)
    drawTopShine(in: ctx, opacity: 0.40)
  case .dark:
    drawLinearGradient(in: ctx, top: darkSlateTop, bottom: darkSlateBottom)
    drawTopShine(in: ctx, opacity: 0.10)
  case .tinted:
    drawLinearGradient(in: ctx, top: tintBgTop, bottom: tintBgBottom)
  }

  // Mark + frame
  let markColor: CGColor
  switch variant {
  case .light: markColor = voidColor
  case .dark, .tinted: markColor = limeColor
  }

  ctx.saveGState()
  ctx.addPath(framePath())
  ctx.setStrokeColor(markColor)
  ctx.setLineWidth(markFrameStroke)
  ctx.strokePath()
  ctx.restoreGState()

  ctx.addPath(markPath())
  ctx.setFillColor(markColor)
  ctx.fillPath(using: .evenOdd)

  ctx.restoreGState()

  // Outer hairline
  ctx.addPath(squircle)
  switch variant {
  case .light:  ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.16))
  case .dark:   ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.06))
  case .tinted: ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
  }
  ctx.setLineWidth(2)
  ctx.strokePath()

  return ctx.makeImage()
}

func drawLinearGradient(in ctx: CGContext, top: CGColor, bottom: CGColor) {
  let cs = CGColorSpaceCreateDeviceRGB()
  guard let g = CGGradient(colorsSpace: cs, colors: [top, bottom] as CFArray, locations: [0, 1]) else { return }
  ctx.drawLinearGradient(
    g,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: 0, y: masterSize),
    options: []
  )
}

func drawBottomShadow(in ctx: CGContext) {
  let cs = CGColorSpaceCreateDeviceRGB()
  let shadow = CGColor(red: 0, green: 0, blue: 0, alpha: 0.18)
  let clear  = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
  guard let g = CGGradient(colorsSpace: cs, colors: [shadow, clear] as CFArray, locations: [0, 1]) else { return }
  ctx.drawRadialGradient(
    g,
    startCenter: CGPoint(x: 512, y: 900),
    startRadius: 0,
    endCenter: CGPoint(x: 512, y: 900),
    endRadius: 520,
    options: []
  )
}

func drawTopShine(in ctx: CGContext, opacity: CGFloat) {
  let cs = CGColorSpaceCreateDeviceRGB()
  let bright = CGColor(red: 1, green: 1, blue: 1, alpha: opacity)
  let clear  = CGColor(red: 1, green: 1, blue: 1, alpha: 0)
  guard let g = CGGradient(colorsSpace: cs, colors: [bright, clear] as CFArray, locations: [0, 1]) else { return }
  ctx.saveGState()
  ctx.clip(to: CGRect(x: 0, y: 0, width: masterSize, height: 380))
  ctx.drawLinearGradient(
    g,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: 0, y: 380),
    options: []
  )
  ctx.restoreGState()
}

// MARK: - PNG writer

func writePNG(_ image: CGImage, to url: URL) throws {
  let rep = NSBitmapImageRep(cgImage: image)
  guard let data = rep.representation(using: .png, properties: [:]) else {
    throw NSError(
      domain: "render-app-icons",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "failed to encode PNG"]
    )
  }
  try data.write(to: url)
}

// MARK: - Driver

let cwd = FileManager.default.currentDirectoryPath
let outputRoot = URL(fileURLWithPath: cwd)
  .appendingPathComponent("Sojourn/Resources/Assets.xcassets/AppIcon.appiconset")

guard FileManager.default.fileExists(atPath: outputRoot.path) else {
  FileHandle.standardError.write(
    "error: \(outputRoot.path) does not exist; run from repo root\n".data(using: .utf8)!
  )
  exit(1)
}

struct OutputSpec {
  let logical: Int
  let scale: Int
  var pixelSize: Int { logical * scale }
  func filename(prefix: String) -> String {
    let suffix = scale == 1 ? "\(logical)x\(logical).png" : "\(logical)x\(logical)@2x.png"
    return prefix.isEmpty ? "icon_\(suffix)" : "\(prefix)_\(suffix)"
  }
}

let specs: [OutputSpec] = [
  .init(logical: 16,  scale: 1),
  .init(logical: 16,  scale: 2),
  .init(logical: 32,  scale: 1),
  .init(logical: 32,  scale: 2),
  .init(logical: 128, scale: 1),
  .init(logical: 128, scale: 2),
  .init(logical: 256, scale: 1),
  .init(logical: 256, scale: 2),
  .init(logical: 512, scale: 1),
  .init(logical: 512, scale: 2)
]

func renderVariant(_ variant: Variant, prefix: String) {
  for spec in specs {
    guard let img = render(variant: variant, size: spec.pixelSize) else {
      FileHandle.standardError.write("error: failed to render \(spec.filename(prefix: prefix))\n".data(using: .utf8)!)
      continue
    }
    let url = outputRoot.appendingPathComponent(spec.filename(prefix: prefix))
    do {
      try writePNG(img, to: url)
      print("wrote \(url.lastPathComponent) (\(spec.pixelSize)×\(spec.pixelSize))")
    } catch {
      FileHandle.standardError.write("error: \(spec.filename(prefix: prefix)): \(error)\n".data(using: .utf8)!)
    }
  }
}

print("Rendering Light variant…")
renderVariant(.light, prefix: "")
print("Rendering Dark variant…")
renderVariant(.dark, prefix: "dark")
print("Rendering Tinted variant…")
renderVariant(.tinted, prefix: "tinted")
print("Done.")
