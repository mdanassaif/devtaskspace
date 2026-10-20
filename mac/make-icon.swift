// Draws the 1024px app icon: soft light squircle with the 2×2 "Today" grid from the app.
import Cocoa

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Background: white to a faint cool grey, with a soft drop shadow like system icons.
let inset: CGFloat = 100, body = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let bg = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgb(0x1E2440, 0.22).cgColor)
rgb(0xFFFFFF).setFill(); bg.fill()
ctx.restoreGState()
NSGradient(colors: [rgb(0xFFFFFF), rgb(0xEEF0F7)])!.draw(in: bg, angle: -90)
rgb(0x1E2440, 0.06).setStroke(); bg.lineWidth = 3; bg.stroke()

// Tiles: tall/short on the left, short/tall on the right; one accent, three soft.
let g: CGFloat = 38, x0: CGFloat = 268, y0: CGFloat = 268, w = (size - 2 * x0 - g) / 2, h = size - 2 * y0
let rects = [
    NSRect(x: x0, y: y0 + h * 0.42 + g / 2, width: w, height: h * 0.58 - g / 2),        // top-left, tall
    NSRect(x: x0, y: y0, width: w, height: h * 0.42 - g / 2),                          // bottom-left
    NSRect(x: x0 + w + g, y: y0 + h * 0.58 + g / 2, width: w, height: h * 0.42 - g / 2), // top-right
    NSRect(x: x0 + w + g, y: y0, width: w, height: h * 0.58 - g / 2),                  // bottom-right, tall
]
let fills: [(UInt32, UInt32)] = [(0x9AA8FF, 0x6F7FF2), (0xBFEBD8, 0x9DDDC2), (0xFFE1B8, 0xFFCC8A), (0xDCE0EE, 0xC9CEE2)]
for (r, (top, bottom)) in zip(rects, fills) {
    let p = NSBezierPath(roundedRect: r, xRadius: 40, yRadius: 40)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: rgb(0x1E2440, 0.10).cgColor)
    rgb(top).setFill(); p.fill()
    ctx.restoreGState()
    NSGradient(colors: [rgb(top), rgb(bottom)])!.draw(in: p, angle: -90)
}
img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
