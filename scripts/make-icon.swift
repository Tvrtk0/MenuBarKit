// Draws the app icon and writes Support/AppIcon.icns (plus a 1024 px preview PNG).
// Run from the repo root: swift scripts/make-icon.swift
//
// Motif: a minimal menu bar — one bold bar over three items, one of them lit —
// on a graphite tile, in the spirit of Apple's own utilities.

import AppKit

let size: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
}

func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
}

func drawIcon() {
    // Tile on Apple's icon grid: 824 pt body, 100 pt margin for the shadow.
    let tile = roundedRect(100, 100, 824, 824, 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0x2A2C31).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(colors: [color(0x4A4D55), color(0x2A2C31), color(0x1B1C20)])!
        .draw(in: tile, angle: -90)
    // Soft sheen along the top edge.
    NSGradient(colors: [color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)])!
        .draw(in: NSRect(x: 100, y: 700, width: 824, height: 224), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Inner edge highlight, as on Apple's dark icons.
    let rim = roundedRect(102, 102, 820, 820, 183)
    rim.lineWidth = 3
    color(0xFFFFFF, 0.08).setStroke()
    rim.stroke()

    // The menu bar.
    color(0xFFFFFF).setFill()
    roundedRect(232, 572, 560, 72, 36).fill()

    // Three items under it; the last one lit.
    color(0xFFFFFF, 0.55).setFill()
    circle(320, 420, 44).fill()
    circle(512, 420, 44).fill()

    let accent = color(0x34C759)
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = accent.withAlphaComponent(0.8)
    glow.shadowBlurRadius = 50
    glow.shadowOffset = .zero
    glow.set()
    accent.setFill()
    circle(704, 420, 44).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let scale = CGFloat(pixels) / size
    context.cgContext.scaleBy(x: scale, y: scale)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try render(1024).write(to: URL(fileURLWithPath: "Support/AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Support/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Support/AppIcon.icns" : "iconutil failed")
