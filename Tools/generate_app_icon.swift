import AppKit
import Foundation

/// Output specification for one PNG inside the app icon set.
private struct IconSpec {
    /// Square pixel size for the generated image.
    let pixels: Int

    /// Destination filename in `AppIcon.appiconset`.
    let filename: String
}

/// PNG sizes required by the app icon asset catalog.
private let specs = [
    IconSpec(pixels: 16, filename: "Icon-16.png"),
    IconSpec(pixels: 32, filename: "Icon-16@2x.png"),
    IconSpec(pixels: 32, filename: "Icon-32.png"),
    IconSpec(pixels: 64, filename: "Icon-32@2x.png"),
    IconSpec(pixels: 128, filename: "Icon-128.png"),
    IconSpec(pixels: 256, filename: "Icon-128@2x.png"),
    IconSpec(pixels: 256, filename: "Icon-256.png"),
    IconSpec(pixels: 512, filename: "Icon-256@2x.png"),
    IconSpec(pixels: 512, filename: "Icon-512.png"),
    IconSpec(pixels: 1024, filename: "Icon-512@2x.png")
]

/// Icon-family chunks written to the generated `.icns` file.
private let icnsChunks: [(type: String, filename: String)] = [
    ("icp4", "Icon-16.png"),
    ("icp5", "Icon-32.png"),
    ("icp6", "Icon-32@2x.png"),
    ("ic07", "Icon-128.png"),
    ("ic08", "Icon-256.png"),
    ("ic09", "Icon-512.png"),
    ("ic10", "Icon-512@2x.png")
]

/// Convenience initializer for AppKit colors expressed as `0xRRGGBB`.
private extension NSColor {
    /// Creates a calibrated RGB color from a packed hex value.
    ///
    /// - Parameters:
    ///   - hex: Red, green, and blue components packed into one value.
    ///   - alpha: Opacity for the resulting color.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}

/// Draws the metronome app icon at a requested square pixel size.
///
/// The drawing coordinates are authored in a 1024-point canvas and scaled down
/// for smaller output sizes to keep all icon variants visually consistent.
///
/// - Parameter pixels: Width and height of the generated bitmap.
/// - Returns: PNG-encoded image data.
private func drawIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
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
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context?.imageInterpolation = .high
    context?.shouldAntialias = true
    context?.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

    let tile = NSBezierPath(roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 210, yRadius: 210)
    NSGraphicsContext.saveGraphicsState()
    let tileShadow = NSShadow()
    tileShadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    tileShadow.shadowBlurRadius = 42
    tileShadow.shadowOffset = NSSize(width: 0, height: -20)
    tileShadow.set()
    NSGradient(colors: [NSColor(hex: 0x1f6f77), NSColor(hex: 0x182832), NSColor(hex: 0x10161d)])?
        .draw(in: tile, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.14).setStroke()
    tile.lineWidth = 5
    tile.stroke()

    let body = NSBezierPath()
    body.move(to: NSPoint(x: 512, y: 802))
    body.line(to: NSPoint(x: 272, y: 210))
    body.curve(to: NSPoint(x: 752, y: 210), controlPoint1: NSPoint(x: 360, y: 158), controlPoint2: NSPoint(x: 664, y: 158))
    body.close()

    NSGraphicsContext.saveGraphicsState()
    let bodyShadow = NSShadow()
    bodyShadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
    bodyShadow.shadowBlurRadius = 24
    bodyShadow.shadowOffset = NSSize(width: 0, height: -12)
    bodyShadow.set()
    NSGradient(colors: [NSColor(hex: 0xf0f2ea), NSColor(hex: 0xcdd9d4), NSColor(hex: 0x879b9b)])?
        .draw(in: body, angle: 92)
    NSGraphicsContext.restoreGraphicsState()

    NSColor(hex: 0x0d2c36).withAlphaComponent(0.45).setStroke()
    body.lineWidth = 11
    body.stroke()

    let inner = NSBezierPath()
    inner.move(to: NSPoint(x: 512, y: 718))
    inner.line(to: NSPoint(x: 356, y: 286))
    inner.curve(to: NSPoint(x: 668, y: 286), controlPoint1: NSPoint(x: 416, y: 252), controlPoint2: NSPoint(x: 608, y: 252))
    inner.close()
    NSGradient(colors: [NSColor(hex: 0x28464f), NSColor(hex: 0x15252d)])?
        .draw(in: inner, angle: 90)

    let scalePath = NSBezierPath()
    scalePath.move(to: NSPoint(x: 442, y: 610))
    scalePath.line(to: NSPoint(x: 582, y: 610))
    scalePath.move(to: NSPoint(x: 424, y: 540))
    scalePath.line(to: NSPoint(x: 600, y: 540))
    scalePath.move(to: NSPoint(x: 404, y: 470))
    scalePath.line(to: NSPoint(x: 620, y: 470))
    NSColor(hex: 0xd7e6dc).withAlphaComponent(0.36).setStroke()
    scalePath.lineWidth = 12
    scalePath.lineCapStyle = .round
    scalePath.stroke()

    let pendulum = NSBezierPath()
    pendulum.move(to: NSPoint(x: 512, y: 704))
    pendulum.line(to: NSPoint(x: 628, y: 318))
    NSColor(hex: 0xff695f).setStroke()
    pendulum.lineWidth = 28
    pendulum.lineCapStyle = .round
    pendulum.stroke()

    NSColor(hex: 0xf7f3e9).setFill()
    NSBezierPath(ovalIn: NSRect(x: 481, y: 673, width: 62, height: 62)).fill()
    NSColor(hex: 0xb92f36).setFill()
    NSBezierPath(ovalIn: NSRect(x: 586, y: 288, width: 84, height: 84)).fill()

    let display = NSBezierPath(roundedRect: NSRect(x: 360, y: 196, width: 304, height: 92), xRadius: 22, yRadius: 22)
    NSColor(hex: 0xb8cec4).setFill()
    display.fill()
    NSColor(hex: 0x0f2a2d).withAlphaComponent(0.4).setStroke()
    display.lineWidth = 6
    display.stroke()

    let beatDot = NSBezierPath(ovalIn: NSRect(x: 486, y: 226, width: 52, height: 52))
    NSColor(hex: 0x213c3d).withAlphaComponent(0.26).setFill()
    beatDot.fill()
    NSColor(hex: 0xff695f).withAlphaComponent(0.88).setFill()
    NSBezierPath(ovalIn: NSRect(x: 498, y: 238, width: 28, height: 28)).fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data
}

/// Asset-catalog destination for generated app icon PNGs.
let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Metronome/Assets.xcassets/AppIcon.appiconset")

/// Regenerate every PNG expected by the asset catalog.
for spec in specs {
    let data = try drawIcon(pixels: spec.pixels)
    try data.write(to: outputDirectory.appendingPathComponent(spec.filename), options: .atomic)
}

/// Build a matching `.icns` file for bundle metadata that still references an
/// icon file directly.
var icns = Data("icns".utf8)
icns.append(UInt32(0).bigEndianData)

for chunk in icnsChunks {
    let png = try Data(contentsOf: outputDirectory.appendingPathComponent(chunk.filename))
    icns.append(Data(chunk.type.utf8))
    icns.append(UInt32(png.count + 8).bigEndianData)
    icns.append(png)
}

let iconLength = UInt32(icns.count).bigEndianData
icns.replaceSubrange(4..<8, with: iconLength)
try icns.write(
    to: outputDirectory
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Metronome.icns"),
    options: .atomic
)

/// Binary encoding helpers for the `.icns` file format.
private extension UInt32 {
    /// Four-byte big-endian representation of the integer.
    var bigEndianData: Data {
        var value = bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}
