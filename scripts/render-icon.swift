// Renders an SVG icon into a macOS .iconset folder at every size iconutil needs.
// Usage: swift scripts/render-icon.swift <source.svg> <output.iconset>
import AppKit

let iconBaseSizes = [16, 32, 128, 256, 512]
let retinaScale = 2

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("render-icon: \(message)\n".utf8))
    exit(EXIT_FAILURE)
}

func renderPNG(of image: NSImage, pixelSize: Int) -> Data {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else {
        fail("could not create a \(pixelSize)px bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fail("could not encode a \(pixelSize)px PNG")
    }
    return pngData
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fail("usage: swift scripts/render-icon.swift <source.svg> <output.iconset>")
}
guard let sourceImage = NSImage(contentsOf: URL(filePath: arguments[1])) else {
    fail("could not read \(arguments[1])")
}
let iconsetURL = URL(filePath: arguments[2], directoryHint: .isDirectory)
do {
    try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
    for baseSize in iconBaseSizes {
        try renderPNG(of: sourceImage, pixelSize: baseSize)
            .write(to: iconsetURL.appending(path: "icon_\(baseSize)x\(baseSize).png"))
        try renderPNG(of: sourceImage, pixelSize: baseSize * retinaScale)
            .write(to: iconsetURL.appending(path: "icon_\(baseSize)x\(baseSize)@2x.png"))
    }
} catch {
    fail("could not write the iconset: \(error.localizedDescription)")
}
