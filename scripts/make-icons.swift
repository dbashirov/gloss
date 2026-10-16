// Draws the app icon (Resources/AppIcon.icns) and the menu bar template icon
// (Resources/StatusIcon.png, StatusIcon@2x.png): two speech bubbles, Latin «A» and
// Cyrillic «Я». Run: swift scripts/make-icons.swift [preview-dir]
import AppKit

let resources = URL(fileURLWithPath: "Resources")
let previewDir = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }

func bitmap(pixels: Int, draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    draw(context.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}

/// A rounded speech bubble with a tail at the bottom-left or bottom-right corner, drawn
/// as one outline so that a stroke follows only its edge.
func bubble(_ rect: CGRect, radius: CGFloat, tailLeft: Bool) -> CGPath {
    let width = rect.width * 0.22
    let depth = rect.height * 0.24
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
    if tailLeft {
        let x = max(rect.minX + rect.width * 0.16, rect.minX + radius)
        path.addLine(to: CGPoint(x: x, y: rect.minY))
        path.addLine(to: CGPoint(x: x - width * 0.35, y: rect.minY - depth))
        path.addLine(to: CGPoint(x: x + width, y: rect.minY))
    } else {
        let x = min(rect.maxX - rect.width * 0.16, rect.maxX - radius)
        path.addLine(to: CGPoint(x: x - width, y: rect.minY))
        path.addLine(to: CGPoint(x: x + width * 0.35, y: rect.minY - depth))
        path.addLine(to: CGPoint(x: x, y: rect.minY))
    }
    let corners = [
        (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)),
        (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)),
        (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.minY)),
        (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + radius, y: rect.minY)),
    ]
    for (corner, next) in corners {
        path.addArc(tangent1End: corner, tangent2End: next, radius: radius)
    }
    path.closeSubpath()
    return path
}

func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
    return NSFont(descriptor: descriptor, size: size) ?? base
}

/// Draws a letter centered in the rect; `clear` punches it out of what is below.
func drawLetter(_ letter: String, in rect: CGRect, size: CGFloat, color: NSColor, clear: Bool = false) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: roundedFont(size: size, weight: .heavy),
        .foregroundColor: color,
    ]
    let text = NSAttributedString(string: letter, attributes: attributes)
    let bounds = text.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin])
    let line = CTLineCreateWithAttributedString(text)
    let glyphs = CTLineGetImageBounds(line, nil)
    let origin = CGPoint(
        x: rect.midX - glyphs.width / 2 - glyphs.minX,
        y: rect.midY - glyphs.height / 2 - glyphs.minY
    )
    _ = bounds
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    if clear {
        context.setBlendMode(.destinationOut)
    }
    context.textPosition = origin
    CTLineDraw(line, context)
    context.restoreGState()
}

// MARK: app icon

func drawAppIcon(_ context: CGContext, pixels: CGFloat) {
    context.scaleBy(x: pixels / 1024, y: pixels / 1024)

    // macOS icon grid: an 824 pt squircle centered on the 1024 canvas
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -10),
        blur: 24,
        color: NSColor.black.withAlphaComponent(0.3).cgColor
    )
    context.addPath(tilePath)
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(srgbRed: 0.42, green: 0.36, blue: 0.98, alpha: 1).cgColor,
            NSColor(srgbRed: 0.19, green: 0.42, blue: 0.95, alpha: 1).cgColor,
            NSColor(srgbRed: 0.05, green: 0.68, blue: 0.86, alpha: 1).cgColor,
        ] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: tile.minX, y: tile.maxY),
        end: CGPoint(x: tile.maxX, y: tile.minY),
        options: []
    )
    // a soft highlight in the upper half
    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.22).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: 330, y: 820),
        startRadius: 0,
        endCenter: CGPoint(x: 330, y: 820),
        endRadius: 560,
        options: []
    )

    // back bubble: the source language
    let back = CGRect(x: 205, y: 455, width: 400, height: 330)
    context.addPath(bubble(back, radius: 96, tailLeft: true))
    context.setFillColor(NSColor.white.withAlphaComponent(0.3).cgColor)
    context.fillPath()
    // the front bubble covers the lower-right corner: the letter sits in the visible part
    drawLetter("A", in: back.offsetBy(dx: -45, dy: 28), size: 230, color: .white)

    // front bubble: the translation
    let front = CGRect(x: 420, y: 265, width: 410, height: 340)
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -14),
        blur: 36,
        color: NSColor(srgbRed: 0.05, green: 0.1, blue: 0.35, alpha: 0.45).cgColor
    )
    context.addPath(bubble(front, radius: 100, tailLeft: false))
    context.setFillColor(NSColor.white.cgColor)
    context.fillPath()
    context.restoreGState()
    drawLetter(
        "Я",
        in: front,
        size: 255,
        color: NSColor(srgbRed: 0.27, green: 0.33, blue: 0.93, alpha: 1)
    )
    context.restoreGState()
}

// MARK: menu bar icon

/// Template image: only the alpha matters, the menu bar tints it.
func drawStatusIcon(_ context: CGContext, pixels: CGFloat) {
    context.scaleBy(x: pixels / 18, y: pixels / 18)
    let back = CGRect(x: 0.8, y: 7.4, width: 10.4, height: 9.2)
    let backPath = bubble(back, radius: 2.8, tailLeft: true)
    context.addPath(backPath)
    context.setStrokeColor(NSColor.black.cgColor)
    context.setLineWidth(1.2)
    context.setLineJoin(.round)
    context.strokePath()
    // the front bubble covers the lower-right corner of the back one
    drawLetter("A", in: back.offsetBy(dx: -1.5, dy: 1.1), size: 5.6, color: .black)

    let front = CGRect(x: 7.4, y: 2.8, width: 10.0, height: 8.4)
    let frontPath = bubble(front, radius: 2.6, tailLeft: false)
    // a gap around the front bubble separates it from the back outline
    context.saveGState()
    context.setBlendMode(.destinationOut)
    context.addPath(frontPath)
    context.setLineWidth(2.4)
    context.strokePath()
    context.restoreGState()
    context.addPath(frontPath)
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    drawLetter("Я", in: front.offsetBy(dx: 0, dy: 0.2), size: 6.2, color: .black, clear: true)
}

let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("AppIcon-\(ProcessInfo.processInfo.processIdentifier).iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let rep = bitmap(pixels: pixels) { drawAppIcon($0, pixels: CGFloat(pixels)) }
        let suffix = scale == 1 ? "" : "@2x"
        try write(rep, to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
    "-c", "icns", iconset.path,
    "-o", resources.appendingPathComponent("AppIcon.icns").path,
]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed with \(iconutil.terminationStatus)")
}

for scale in [1, 2] {
    let rep = bitmap(pixels: 18 * scale) { drawStatusIcon($0, pixels: CGFloat(18 * scale)) }
    rep.size = NSSize(width: 18, height: 18)
    let name = scale == 1 ? "StatusIcon.png" : "StatusIcon@2x.png"
    try write(rep, to: resources.appendingPathComponent(name))
}

if let previewDir {
    try FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)
    try write(
        bitmap(pixels: 512) { drawAppIcon($0, pixels: 512) },
        to: previewDir.appendingPathComponent("app-512.png")
    )
    try write(
        bitmap(pixels: 64) { drawAppIcon($0, pixels: 64) },
        to: previewDir.appendingPathComponent("app-64.png")
    )
    try write(
        bitmap(pixels: 144) { drawStatusIcon($0, pixels: 144) },
        to: previewDir.appendingPathComponent("status-144.png")
    )
    // the real @2x size on a light and a dark menu bar, magnified without smoothing
    let actual = bitmap(pixels: 36) { drawStatusIcon($0, pixels: 36) }
    let sheet = bitmap(pixels: 288) { context in
        context.interpolationQuality = .none
        for (index, color) in [NSColor(white: 0.92, alpha: 1), NSColor(white: 0.16, alpha: 1)].enumerated() {
            let cell = CGRect(x: CGFloat(index) * 144, y: 72, width: 144, height: 144)
            context.setFillColor(color.cgColor)
            context.fill(cell)
            let tinted = bitmap(pixels: 36) { tint in
                tint.draw(actual.cgImage!, in: CGRect(x: 0, y: 0, width: 36, height: 36))
                tint.setBlendMode(.sourceIn)
                tint.setFillColor(index == 0 ? NSColor.black.cgColor : NSColor.white.cgColor)
                tint.fill(CGRect(x: 0, y: 0, width: 36, height: 36))
            }
            context.draw(tinted.cgImage!, in: cell)
        }
    }
    try write(sheet, to: previewDir.appendingPathComponent("status-actual.png"))
}
try? FileManager.default.removeItem(at: iconset)
print("wrote Resources/AppIcon.icns, Resources/StatusIcon.png, Resources/StatusIcon@2x.png")
