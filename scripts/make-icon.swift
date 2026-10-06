import AppKit
import Foundation

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot create icon canvas") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let side = CGFloat(size)
    NSColor(srgbRed: 40 / 255, green: 117 / 255, blue: 106 / 255, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: side * 0.04, y: side * 0.04, width: side * 0.92, height: side * 0.92), xRadius: side * 0.21, yRadius: side * 0.21).fill()
    let font = NSFont.systemFont(ofSize: side * 0.75, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(srgbRed: 252 / 255, green: 251 / 255, blue: 248 / 255, alpha: 1)]
    let text = "r" as NSString
    let measured = text.size(withAttributes: attributes)
    text.draw(at: NSPoint(x: (side - measured.width) / 2, y: (side - measured.height) / 2 + side * 0.02), withAttributes: attributes)
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon") }
    if size <= 512 { try data.write(to: folder.appendingPathComponent("icon_\(size)x\(size).png")) }
    if size >= 32 { try data.write(to: folder.appendingPathComponent("icon_\(size / 2)x\(size / 2)@2x.png")) }
}
