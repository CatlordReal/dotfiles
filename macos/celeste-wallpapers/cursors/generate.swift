import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Pixel {
    let x: Int
    let y: Int
    let color: CGColor
}

struct CursorDesign {
    let name: String
    let identifiers: [String]
    let hotSpot: CGPoint
    let pixels: [Pixel]
}

let clear = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
let outline = CGColor(red: 0.08, green: 0.10, blue: 0.19, alpha: 1)
let snow = CGColor(red: 0.96, green: 0.94, blue: 1.00, alpha: 1)
let berry = CGColor(red: 0.91, green: 0.19, blue: 0.31, alpha: 1)
let berryLight = CGColor(red: 1.00, green: 0.42, blue: 0.48, alpha: 1)
let sky = CGColor(red: 0.31, green: 0.78, blue: 0.94, alpha: 1)
let skyDark = CGColor(red: 0.12, green: 0.43, blue: 0.67, alpha: 1)
let leaf = CGColor(red: 0.36, green: 0.82, blue: 0.48, alpha: 1)
let gold = CGColor(red: 1.00, green: 0.79, blue: 0.30, alpha: 1)

func p(_ x: Int, _ y: Int, _ color: CGColor) -> Pixel { Pixel(x: x, y: y, color: color) }

func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ color: CGColor) -> [Pixel] {
    var result: [Pixel] = []
    var x = x0, y = y0
    let dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1
    let dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1
    var error = dx + dy
    while true {
        result.append(p(x, y, color))
        if x == x1 && y == y1 { break }
        let twice = 2 * error
        if twice >= dy { error += dy; x += sx }
        if twice <= dx { error += dx; y += sy }
    }
    return result
}

func rect(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: CGColor) -> [Pixel] {
    (y..<(y + height)).flatMap { row in (x..<(x + width)).map { p($0, row, color) } }
}

func span(_ y: Int, _ x0: Int, _ x1: Int, _ color: CGColor) -> [Pixel] {
    (x0...x1).map { p($0, y, color) }
}

// Original strawberry cursor: leaf tip at (1, 1), tapered berry below.
let arrow: [Pixel] =
    span(1, 1, 2, outline) + span(1, 5, 6, outline) +
    span(2, 1, 7, outline) + span(3, 2, 9, outline) +
    span(4, 3, 10, outline) + span(5, 2, 11, outline) +
    span(6, 2, 12, outline) + span(7, 2, 12, outline) +
    span(8, 3, 12, outline) + span(9, 3, 11, outline) +
    span(10, 4, 11, outline) + span(11, 5, 10, outline) +
    span(12, 6, 9, outline) + span(13, 7, 8, outline) +
    span(2, 2, 6, leaf) + span(3, 3, 5, leaf) +
    [p(6,3,leaf), p(8,3,leaf), p(4,4,leaf), p(6,4,leaf)] +
    span(4, 5, 9, berry) + span(5, 3, 10, berry) +
    span(6, 3, 11, berry) + span(7, 3, 11, berry) +
    span(8, 4, 11, berry) + span(9, 4, 10, berry) +
    span(10, 5, 10, berry) + span(11, 6, 9, berry) +
    span(12, 7, 8, berry) +
    [p(5,5,berryLight), p(4,6,berryLight), p(4,7,berryLight),
     p(7,6,snow), p(10,7,snow), p(5,8,snow), p(8,9,snow), p(7,11,snow)]

let ibeam = line(7, 2, 7, 13, outline) + line(8, 2, 8, 13, sky) +
    line(5, 2, 10, 2, outline) + line(5, 13, 10, 13, outline) +
    [p(8,5,snow), p(8,8,snow), p(8,11,snow)]

// Link cursor uses a rounder berry, gold seeds, and a gold motion dash.
let hand =
    span(2, 4, 5, outline) + span(2, 9, 10, outline) +
    span(3, 4, 10, outline) + span(4, 3, 11, outline) +
    span(5, 2, 12, outline) + span(6, 2, 13, outline) +
    span(7, 2, 13, outline) + span(8, 2, 13, outline) +
    span(9, 3, 12, outline) + span(10, 3, 12, outline) +
    span(11, 4, 11, outline) + span(12, 5, 10, outline) +
    span(13, 6, 9, outline) +
    span(3, 5, 9, leaf) + [p(3,4,leaf), p(10,4,leaf), p(6,4,leaf), p(8,4,leaf)] +
    span(4, 4, 10, berry) + span(5, 3, 11, berry) +
    span(6, 3, 12, berry) + span(7, 3, 12, berry) +
    span(8, 3, 12, berry) + span(9, 4, 11, berry) +
    span(10, 4, 11, berry) + span(11, 5, 10, berry) +
    span(12, 6, 9, berry) +
    [p(4,5,berryLight), p(4,6,berryLight), p(5,6,berryLight),
     p(7,6,gold), p(10,6,gold), p(5,8,gold), p(8,9,gold), p(10,10,gold)] +
    span(6, 14, 15, gold) + span(8, 14, 15, gold)

let crosshair = line(2,8,13,8,outline) + line(8,2,8,13,outline) +
    line(4,8,6,8,sky) + line(10,8,12,8,sky) + line(8,4,8,6,sky) + line(8,10,8,12,sky) +
    rect(7,7,3,3,snow)

let busy = line(8,2,8,13,outline) + line(2,8,13,8,outline) +
    line(4,4,12,12,outline) + line(12,4,4,12,outline) +
    [p(8,2,berry),p(13,8,berryLight),p(8,13,sky),p(2,8,skyDark),p(4,4,gold),p(12,4,leaf),p(12,12,berry),p(4,12,snow)]

let forbidden = line(4,4,11,11,outline) + line(3,4,11,12,berry) +
    line(5,3,12,10,berryLight) +
    [p(7,2,outline),p(8,2,outline),p(4,3,outline),p(11,3,outline),p(3,4,outline),p(12,4,outline),p(2,7,outline),p(13,7,outline),p(2,8,outline),p(13,8,outline),p(3,11,outline),p(12,11,outline),p(4,12,outline),p(11,12,outline),p(7,13,outline),p(8,13,outline)]

let resizeNS = line(8,2,8,13,outline) + line(7,3,7,12,sky) +
    line(5,5,8,2,outline) + line(8,2,11,5,outline) + line(5,10,8,13,outline) + line(8,13,11,10,outline)
let resizeEW = line(2,8,13,8,outline) + line(3,7,12,7,sky) +
    line(5,5,2,8,outline) + line(2,8,5,11,outline) + line(10,5,13,8,outline) + line(13,8,10,11,outline)
let resizeNWSE = line(3,3,12,12,outline) + line(4,3,12,11,sky) +
    line(3,3,7,3,outline) + line(3,3,3,7,outline) + line(12,12,8,12,outline) + line(12,12,12,8,outline)
let resizeNESW = line(12,3,3,12,outline) + line(11,3,3,11,sky) +
    line(12,3,8,3,outline) + line(12,3,12,7,outline) + line(3,12,7,12,outline) + line(3,12,3,8,outline)
let move = resizeNS + resizeEW

let designs = [
    CursorDesign(name: "arrow", identifiers: ["com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS", "com.apple.coregraphics.ArrowCtx"], hotSpot: CGPoint(x: 2, y: 2), pixels: arrow),
    CursorDesign(name: "ibeam", identifiers: ["com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamS", "com.apple.coregraphics.IBeamXOR", "com.apple.cursor.26"], hotSpot: CGPoint(x: 16, y: 16), pixels: ibeam),
    CursorDesign(name: "hand", identifiers: ["com.apple.cursor.2", "com.apple.cursor.13", "com.apple.cursor.12", "com.apple.cursor.11"], hotSpot: CGPoint(x: 8, y: 4), pixels: hand),
    CursorDesign(name: "crosshair", identifiers: ["com.apple.cursor.7", "com.apple.cursor.8", "com.apple.cursor.20"], hotSpot: CGPoint(x: 16, y: 16), pixels: crosshair),
    CursorDesign(name: "busy", identifiers: ["com.apple.cursor.4", "com.apple.coregraphics.Wait"], hotSpot: CGPoint(x: 16, y: 16), pixels: busy),
    CursorDesign(name: "forbidden", identifiers: ["com.apple.cursor.3"], hotSpot: CGPoint(x: 16, y: 16), pixels: forbidden),
    CursorDesign(name: "resize-ns", identifiers: ["com.apple.cursor.23", "com.apple.cursor.32"], hotSpot: CGPoint(x: 16, y: 16), pixels: resizeNS),
    CursorDesign(name: "resize-ew", identifiers: ["com.apple.cursor.19", "com.apple.cursor.28"], hotSpot: CGPoint(x: 16, y: 16), pixels: resizeEW),
    CursorDesign(name: "resize-nwse", identifiers: ["com.apple.cursor.34"], hotSpot: CGPoint(x: 16, y: 16), pixels: resizeNWSE),
    CursorDesign(name: "resize-nesw", identifiers: ["com.apple.cursor.30"], hotSpot: CGPoint(x: 16, y: 16), pixels: resizeNESW),
    CursorDesign(name: "move", identifiers: ["com.apple.coregraphics.Move"], hotSpot: CGPoint(x: 16, y: 16), pixels: move)
]

func png(design: CursorDesign, scale: Int) throws -> Data {
    let side = 32 * scale
    guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let destinationData = CFDataCreateMutable(nil, 0),
          let destination = CGImageDestinationCreateWithData(destinationData, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    context.setFillColor(clear)
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    context.interpolationQuality = .none
    let cell = 2 * scale
    for pixel in design.pixels {
        context.setFillColor(pixel.color)
        context.fill(CGRect(x: pixel.x * cell, y: side - (pixel.y + 1) * cell, width: cell, height: cell))
    }
    guard let image = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    return destinationData as Data
}

let script = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let root = script.deletingLastPathComponent()
let assets = root.appendingPathComponent("assets", isDirectory: true)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

var cursors: [String: Any] = [:]
for design in designs {
    let one = try png(design: design, scale: 1)
    let two = try png(design: design, scale: 2)
    try one.write(to: assets.appendingPathComponent("\(design.name)@1x.png"), options: .atomic)
    try two.write(to: assets.appendingPathComponent("\(design.name)@2x.png"), options: .atomic)
    let entry: [String: Any] = [
        "FrameCount": 1,
        "FrameDuration": 0.0,
        "HotSpotX": design.hotSpot.x,
        "HotSpotY": design.hotSpot.y,
        "PointsWide": 32.0,
        "PointsHigh": 32.0,
        "Representations": [one, two]
    ]
    for identifier in design.identifiers { cursors[identifier] = entry }
}

let cape: [String: Any] = [
    "Author": "Kian Conti",
    "CapeName": "Celeste Pixel",
    "CapeVersion": 1.0,
    "Cloud": false,
    "HiDPI": true,
    "Identifier": "com.kianconti.celeste-pixel",
    "MinimumVersion": 2.0,
    "Version": 2.0,
    "Cursors": cursors
]
let data = try PropertyListSerialization.data(fromPropertyList: cape, format: .binary, options: 0)
try data.write(to: root.appendingPathComponent("Celeste.cape"), options: .atomic)
print("Generated \(designs.count) designs, \(cursors.count) cursor identifiers")
