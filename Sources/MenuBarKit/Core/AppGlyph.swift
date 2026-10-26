import AppKit

/// The app icon's motif — a bar over three items, the last one lit — as an 18 pt
/// template image for the menu bar. Templates are tinted by the system, so the lit
/// item is told apart by opacity rather than colour.
enum AppGlyph {
    static let menuBar: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 2, y: 5, width: 14, height: 2.5), xRadius: 1.25, yRadius: 1.25).fill()
            for (x, alpha) in [(2.6, 0.4), (7.4, 0.4), (12.2, 1.0)] {
                NSColor.black.withAlphaComponent(alpha).setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: 9.9, width: 3.2, height: 3.2)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
