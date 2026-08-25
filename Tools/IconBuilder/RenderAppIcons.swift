//
//  RenderAppIcons.swift
//  Tools/IconBuilder
//
//  Renders Noor's app icon at every size and variant the two asset catalogs ask for.
//
//  Run:  swift Tools/IconBuilder/RenderAppIcons.swift
//
//  The icon is *drawn*, not exported. It is four shapes over a gradient — an arc, a sun, a
//  horizon and the girih lattice — and every one of them is placed as a fraction of the canvas,
//  so the same code is correct at 16 points and at 1024. A hand export is correct at exactly one
//  size and quietly wrong at the others, which is how a Dock icon ends up soft and a Home Screen
//  icon ends up with a horizon two pixels thick.
//
//  The fractions below are the `NoorIcon` component from the Claude Design canvas, transcribed.
//  Change them there and here together.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - The palette

struct Stop {
    let location: CGFloat
    let rgb: UInt32
}

struct Variant {
    let name: String
    /// The ground, top to bottom.
    let ground: [Stop]
    /// The arc, the sun and the horizon — one colour, because they are one drawing.
    let mark: UInt32
    let lattice: UInt32
    let latticeOpacity: CGFloat
    let glow: UInt32
    let glowOpacity: CGFloat
    /// macOS icons sit inside their canvas with margins and carry their own rounded shape; iOS
    /// icons are full-bleed squares that the system masks.
    let isMac: Bool

    static let iosLight = Variant(
        name: "light",
        ground: [Stop(location: 0, rgb: 0x1B1B2E), Stop(location: 0.38, rgb: 0x3E4C63),
                 Stop(location: 0.80, rgb: 0xB4682F), Stop(location: 1, rgb: 0xE8B65C)],
        mark: 0xFFF3DD, lattice: 0xFFEBC8, latticeOpacity: 0.16,
        glow: 0xFFD68C, glowOpacity: 0.62, isMac: false
    )

    static let iosDark = Variant(
        name: "dark",
        ground: [Stop(location: 0, rgb: 0x07070E), Stop(location: 0.34, rgb: 0x141B2A),
                 Stop(location: 0.78, rgb: 0x43220F), Stop(location: 1, rgb: 0x7A3F12)],
        mark: 0xFFE7BC, lattice: 0xFFE7BC, latticeOpacity: 0.13,
        glow: 0xFFCD7C, glowOpacity: 0.50, isMac: false
    )

    /// Grey on purpose. iOS renders the tinted variant by taking the *luminance* of what is
    /// supplied and tinting it, so anything coloured here is thrown away — and a variant drawn in
    /// amber would come out with its arc and its ground at almost the same grey.
    static let iosTinted = Variant(
        name: "tinted",
        ground: [Stop(location: 0, rgb: 0x3A3A3A), Stop(location: 0.46, rgb: 0x5E5E5E),
                 Stop(location: 1, rgb: 0x8E8E8E)],
        mark: 0xFFFFFF, lattice: 0xFFFFFF, latticeOpacity: 0.10,
        glow: 0xFFFFFF, glowOpacity: 0.28, isMac: false
    )

    static let mac = Variant(
        name: "mac",
        ground: Variant.iosLight.ground,
        mark: 0xFFF3DD, lattice: 0xFFEBC8, latticeOpacity: 0.16,
        glow: 0xFFD68C, glowOpacity: 0.62, isMac: true
    )
}

// MARK: - Drawing

func components(_ rgb: UInt32, _ alpha: CGFloat = 1) -> [CGFloat] {
    [CGFloat((rgb >> 16) & 0xFF) / 255,
     CGFloat((rgb >> 8) & 0xFF) / 255,
     CGFloat(rgb & 0xFF) / 255,
     alpha]
}

func makeColor(_ rgb: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: components(rgb, alpha))!
}

/// Draws the icon at `side` pixels square.
///
/// The context is y-down (the transform below flips it) so that every fraction reads the same way
/// round as the design's, which measures everything from the top.
func renderIcon(variant: Variant, side: CGFloat) -> CGImage {
    let context = CGContext(
        data: nil,
        width: Int(side),
        height: Int(side),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    context.translateBy(x: 0, y: side)
    context.scaleBy(x: 1, y: -1)
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    let innerFraction: CGFloat = variant.isMac ? 0.82 : 1
    let inner = side * innerFraction
    let origin = (side - inner) / 2
    let box = CGRect(x: origin, y: origin, width: inner, height: inner)
    func f(_ fraction: CGFloat) -> CGFloat { inner * fraction }

    context.saveGState()

    // The shape. iOS is a full-bleed square the system masks itself; macOS carries its own
    // rounded rect, because a Mac icon is composited onto the Dock as it is drawn.
    if variant.isMac {
        // A soft contact shadow under the tile, which is what stops a Mac icon looking pasted on.
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -f(0.03)),
            blur: f(0.075),
            color: makeColor(0x000000, 0.34)
        )
        context.addPath(CGPath(roundedRect: box, cornerWidth: f(0.225), cornerHeight: f(0.225), transform: nil))
        context.setFillColor(makeColor(0x000000, 1))
        context.fillPath()
        context.restoreGState()

        context.addPath(CGPath(roundedRect: box, cornerWidth: f(0.225), cornerHeight: f(0.225), transform: nil))
        context.clip()
    } else {
        context.addRect(box)
        context.clip()
    }

    // 1. The ground.
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: variant.ground.map { makeColor($0.rgb) } as CFArray,
        locations: variant.ground.map(\.location)
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: box.midX, y: box.minY),
        end: CGPoint(x: box.midX, y: box.maxY),
        options: []
    )

    // 2. The girih lattice, drawn past every edge so no line ends inside the tile.
    context.saveGState()
    context.setStrokeColor(makeColor(variant.lattice, variant.latticeOpacity))
    context.setLineWidth(max(0.6, f(0.007)))
    let gap = f(0.115)
    let reach = inner * 1.4
    var offset = box.minX - reach
    while offset <= box.maxX + reach {
        context.move(to: CGPoint(x: offset, y: box.minY - reach))
        context.addLine(to: CGPoint(x: offset + 2 * reach, y: box.minY - reach + 2 * reach))
        context.move(to: CGPoint(x: offset, y: box.minY - reach))
        context.addLine(to: CGPoint(x: offset - 2 * reach, y: box.minY - reach + 2 * reach))
        offset += gap * 2.0.squareRoot()
    }
    context.strokePath()
    context.restoreGState()

    // 3. The arc — the day's path, and the reason the icon reads as this app rather than as a
    //    sunrise stock glyph. Only the top quarter is painted, which is what CSS's
    //    `border-top-color` on a circle draws.
    let arcSide = f(1.02)
    let arcBox = CGRect(x: box.minX + f(-0.01), y: box.minY + f(0.315), width: arcSide, height: arcSide)
    let arcWidth = max(1.4, f(0.075))
    context.saveGState()
    context.setStrokeColor(makeColor(variant.mark))
    context.setLineWidth(arcWidth)
    context.setLineCap(.butt)
    context.addArc(
        center: CGPoint(x: arcBox.midX, y: arcBox.midY),
        radius: (arcSide - arcWidth) / 2,
        startAngle: .pi * 1.25,
        endAngle: .pi * 1.75,
        clockwise: false
    )
    context.strokePath()
    context.restoreGState()

    // 4. The sun, with its glow.
    let sunSide = f(0.215)
    let sunCentre = CGPoint(x: box.midX, y: box.minY + f(0.245) + sunSide / 2)
    context.saveGState()
    let glowGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [makeColor(variant.glow, variant.glowOpacity), makeColor(variant.glow, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glowGradient,
        startCenter: sunCentre,
        startRadius: sunSide / 2,
        endCenter: sunCentre,
        endRadius: sunSide / 2 + f(0.028) + f(0.10),
        options: []
    )
    context.setFillColor(makeColor(variant.mark))
    context.fillEllipse(in: CGRect(
        x: sunCentre.x - sunSide / 2,
        y: sunCentre.y - sunSide / 2,
        width: sunSide,
        height: sunSide
    ))
    context.restoreGState()

    // 5. The horizon.
    let horizonHeight = max(1, f(0.022))
    let horizon = CGRect(
        x: box.minX + f(0.16),
        y: box.minY + f(0.795),
        width: inner - f(0.32),
        height: horizonHeight
    )
    context.setFillColor(makeColor(variant.mark, 0.62))
    context.addPath(CGPath(
        roundedRect: horizon,
        cornerWidth: horizonHeight / 2,
        cornerHeight: horizonHeight / 2,
        transform: nil
    ))
    context.fillPath()

    context.restoreGState()
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    )!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        FileHandle.standardError.write(Data("could not write \(url.path)\n".utf8))
        exit(1)
    }
}

// MARK: - What each catalog needs

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconSet = root.appending(path: "ThawabForGod/Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: appIconSet, withIntermediateDirectories: true)

/// iOS wants one 1024 square per appearance; the system masks and scales them.
for variant in [Variant.iosLight, .iosDark, .iosTinted] {
    let image = renderIcon(variant: variant, side: 1024)
    write(image, to: appIconSet.appending(path: "AppIcon-\(variant.name).png"))
}

/// macOS wants every size drawn at its own pixel count, because the small ones are not the large
/// one scaled down — a horizon at 16 points has to be a whole pixel or it disappears.
let macSizes: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]
for size in macSizes {
    let pixels = size.points * size.scale
    let image = renderIcon(variant: .mac, side: CGFloat(pixels))
    write(image, to: appIconSet.appending(path: "AppIcon-mac-\(size.points)x\(size.points)@\(size.scale)x.png"))
}

print("wrote \(3 + macSizes.count) images to \(appIconSet.path)")
