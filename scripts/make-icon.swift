// Draws the app icon and writes Support/AppIcon.icns (plus a 1024 px preview PNG).
// Run from the repo root: swift scripts/make-icon.swift
//
// Motif: a menu bar with one highlighted item dropping a popover card — the
// app's whole idea at a glance. Colours match the Spotify mockup palette.

import AppKit

let size: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
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
    color(0x3A1466).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(colors: [color(0x2A0F52), color(0x6B1F8A), color(0xA02F7C)])!
        .draw(in: tile, angle: -60)
    NSGradient(colors: [color(0xFF7A45, 0.55), color(0xFF7A45, 0)])!
        .draw(fromCenter: NSPoint(x: 180, y: 160), radius: 0, toCenter: NSPoint(x: 180, y: 160), radius: 620, options: [])

    // Background waves, faint.
    for (i, alpha) in [0.10, 0.16, 0.10].enumerated() {
        let y = 300 + CGFloat(i) * 46
        let wave = NSBezierPath()
        wave.move(to: NSPoint(x: 80, y: y))
        wave.curve(to: NSPoint(x: 520, y: y + 10), controlPoint1: NSPoint(x: 230, y: y + 140), controlPoint2: NSPoint(x: 380, y: y - 120))
        wave.curve(to: NSPoint(x: 950, y: y + 40), controlPoint1: NSPoint(x: 680, y: y + 140), controlPoint2: NSPoint(x: 820, y: y - 60))
        wave.lineWidth = 10
        color(0xFFD2A8, alpha).setStroke()
        wave.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    // Menu bar.
    color(0xFFFFFF, 0.93).setFill()
    roundedRect(170, 700, 684, 96, 48).fill()
    color(0x3A1466, 0.55).setFill()
    NSBezierPath(ovalIn: NSRect(x: 222, y: 728, width: 40, height: 40)).fill()
    color(0x3A1466, 0.3).setFill()
    roundedRect(282, 736, 88, 24, 12).fill()
    // Highlighted item (the module whose popover is open).
    color(0xFF7A45).setFill()
    roundedRect(418, 718, 188, 60, 30).fill()
    color(0xFFFFFF, 0.95).setFill()
    roundedRect(446, 739, 18, 18, 5).fill()
    roundedRect(476, 742, 104, 12, 6).fill()
    color(0x3A1466, 0.3).setFill()
    NSBezierPath(ovalIn: NSRect(x: 660, y: 732, width: 32, height: 32)).fill()
    roundedRect(712, 736, 88, 24, 12).fill()

    // Popover card with its arrow.
    NSGraphicsContext.saveGraphicsState()
    let cardShadow = NSShadow()
    cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    cardShadow.shadowBlurRadius = 30
    cardShadow.shadowOffset = NSSize(width: 0, height: -10)
    cardShadow.set()
    // One transparency layer so card and arrow cast a single shadow with no seam.
    let cg = NSGraphicsContext.current!.cgContext
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    color(0xFFFFFF, 0.97).setFill()
    roundedRect(262, 214, 500, 430, 52).fill()
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 472, y: 630))
    arrow.line(to: NSPoint(x: 512, y: 688))
    arrow.line(to: NSPoint(x: 552, y: 630))
    arrow.close()
    arrow.fill()
    cg.endTransparencyLayer()
    NSGraphicsContext.restoreGraphicsState()

    // Card content: artwork, two text lines, progress, play button.
    let art = roundedRect(306, 456, 150, 150, 26)
    NSGraphicsContext.saveGraphicsState()
    art.addClip()
    NSGradient(colors: [color(0x3A1466), color(0xA02F7C)])!.draw(in: art, angle: -45)
    for (i, hex) in [0xFFFFFF, 0xFF9A5C].enumerated() {
        let y = 520 + CGFloat(i) * 26
        let wave = NSBezierPath()
        wave.move(to: NSPoint(x: 296, y: y))
        wave.curve(to: NSPoint(x: 470, y: y + 10), controlPoint1: NSPoint(x: 350, y: y + 50), controlPoint2: NSPoint(x: 410, y: y - 40))
        wave.lineWidth = 9
        color(UInt32(hex), 0.85).setStroke()
        wave.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    color(0x2A0F52, 0.85).setFill()
    roundedRect(486, 562, 230, 26, 13).fill()
    color(0x2A0F52, 0.35).setFill()
    roundedRect(486, 516, 160, 22, 11).fill()

    color(0x2A0F52, 0.12).setFill()
    roundedRect(306, 398, 412, 16, 8).fill()
    color(0xFF7A45).setFill()
    roundedRect(306, 398, 250, 16, 8).fill()

    color(0x2A0F52, 0.85).setFill()
    let play = NSBezierPath()
    play.move(to: NSPoint(x: 492, y: 262))
    play.line(to: NSPoint(x: 492, y: 346))
    play.line(to: NSPoint(x: 560, y: 304))
    play.close()
    play.fill()
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
