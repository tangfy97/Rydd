// Renders Design/AppIcon.svg into the asset catalog at every size (the Xcode builds) and into
// Design/AppIcon.icns (the Swift package development build), plus a 1024 px preview.
//
//   swift scripts/icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let design = root.appendingPathComponent("Design")
let catalog = root.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset")
guard let svg = NSImage(contentsOf: design.appendingPathComponent("AppIcon.svg")) else {
    fatalError("could not load AppIcon.svg")
}

func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    svg.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Asset catalog
try FileManager.default.createDirectory(at: catalog, withIntermediateDirectories: true)
for px in [16, 32, 64, 128, 256, 512, 1024] {
    try png(px).write(to: catalog.appendingPathComponent("icon_\(px).png"))
}
let entries = [(16, "1x", 16), (16, "2x", 32), (32, "1x", 32), (32, "2x", 64), (128, "1x", 128),
               (128, "2x", 256), (256, "1x", 256), (256, "2x", 512), (512, "1x", 512), (512, "2x", 1024)]
let images = entries.map { size, scale, px in
    #"    { "filename" : "icon_\#(px).png", "idiom" : "mac", "scale" : "\#(scale)", "size" : "\#(size)x\#(size)" }"#
}.joined(separator: ",\n")
try """
{
  "images" : [
\(images)
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

""".write(to: catalog.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try #"{ "info" : { "author" : "xcode", "version" : 1 } }"#.write(
    to: catalog.deletingLastPathComponent().appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// .icns and preview
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try png(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try png(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try png(1024).write(to: design.appendingPathComponent("AppIcon-1024.png"))
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", design.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "wrote the asset catalog, Design/AppIcon.icns and Design/AppIcon-1024.png" : "iconutil failed")
