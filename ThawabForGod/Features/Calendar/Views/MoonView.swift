//
//  MoonView.swift
//  ThawabForGod
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Which half of the Earth the viewer is on, which decides which side of the Moon is lit.
///
/// A waxing Moon is lit on the right from the northern hemisphere and on the left from the
/// southern. It belongs to the drawing, not to the calculator: the phase is the same everywhere.
nonisolated enum MoonHemisphere: Sendable {
    case northern, southern

    /// Northern when the latitude is unknown, which is where most readers are.
    init(latitude: Double?) {
        self = (latitude ?? 1) < 0 ? .southern : .northern
    }
}

/// The Moon drawn exactly, for any illuminated fraction, from paths rather than image assets.
///
/// The lit region is bounded by the outer limb on one side and the terminator on the other, and
/// the terminator is half an ellipse as wide as `r · |1 − 2k|` — a crescent bulges it toward the
/// lit side, a gibbous toward the dark.
///
/// **Not mirrored by the layout direction.** The Moon's lit side is physics, not reading order,
/// so it is decided from `isWaxing` and `hemisphere` alone. `Canvas` is never flipped for
/// right-to-left, and nothing here asks it to be.
///
/// Drawn in the ink of the day ramp, for a dark ground — the Moon card and the Home card both
/// are one.
struct MoonView: View {
    let illuminatedFraction: Double
    let isWaxing: Bool
    var hemisphere: MoonHemisphere = .northern
    var accessibilityText: String

    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var litOnRight: Bool { isWaxing == (hemisphere == .northern) }

    /// Whether the bundled photograph is there. The drawn moon below is what a build without it
    /// keeps, so the view never depends on the file being present.
    static let hasTexture: Bool = {
        #if canImport(UIKit)
        UIImage(named: "MoonNearside") != nil
        #elseif canImport(AppKit)
        NSImage(named: "MoonNearside") != nil
        #else
        false
        #endif
    }()

    /// How much of the unlit side still shows: earthshine, not a black cut-out.
    private static let earthshine = 0.08

    /// The terminator's soft edge, as a fraction of the radius.
    private static let feather = 0.035

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        if Self.hasTexture {
            drawPhotograph(in: &context, size: size)
        } else {
            drawIllustration(in: &context, size: size)
        }
    }

    /// The photograph as a disc, with the unlit part darkened to earthshine along the terminator.
    ///
    /// The picture is the near side as seen from the northern hemisphere. From the southern one
    /// the same face is upside down, so it is turned half a revolution there — physics, and for
    /// the same reason the lit side is decided from `isWaxing` and `hemisphere`, never from the
    /// layout direction.
    private func drawPhotograph(in context: inout GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let ink = theme.onDayRamp
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let disc = Path(ellipseIn: rect)

        let glow = Path(ellipseIn: rect.insetBy(dx: -radius * 0.5, dy: -radius * 0.5))
        context.fill(glow, with: .radialGradient(
            Gradient(colors: [ink.textPrimary.opacity(0.22 * illuminatedFraction), .clear]),
            center: center, startRadius: radius * 0.9, endRadius: radius * 1.5))

        context.drawLayer { layer in
            layer.clip(to: disc)

            var picture = layer
            if hemisphere == .southern {
                picture.translateBy(x: center.x, y: center.y)
                picture.rotate(by: .degrees(180))
                picture.translateBy(x: -center.x, y: -center.y)
            }
            picture.draw(layer.resolve(Image("MoonNearside")), in: rect)

            // Shade everything, then cut the lit region back out; blurring the layer is what
            // softens the terminator.
            layer.drawLayer { shade in
                shade.addFilter(.blur(radius: radius * Self.feather))
                shade.fill(disc, with: .color(.black.opacity(1 - Self.earthshine)))
                shade.blendMode = .destinationOut
                shade.fill(litPath(center: center, radius: radius), with: .color(.black))
            }
        }
    }

    private func drawIllustration(in context: inout GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let ink = theme.onDayRamp

        // Glow: a soft halo that grows with how much of the Moon is lit.
        let glow = Path(ellipseIn: CGRect(x: center.x - radius * 1.5, y: center.y - radius * 1.5,
                                          width: radius * 3, height: radius * 3))
        context.fill(glow, with: .radialGradient(
            Gradient(colors: [ink.textPrimary.opacity(0.22 * illuminatedFraction), .clear]),
            center: center, startRadius: radius * 0.9, endRadius: radius * 1.5))

        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        context.fill(disc, with: .color(ink.surface))

        let lit = litPath(center: center, radius: radius)
        context.fill(lit, with: .color(ink.textPrimary))

        context.clip(to: lit)
        for crater in Self.craters {
            let r = radius * crater.radius
            let rect = CGRect(x: center.x + radius * crater.x - r, y: center.y + radius * crater.y - r,
                              width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(ink.surface.opacity(0.7)))
        }
    }

    /// Outer limb down the lit side, then back up along the terminator.
    private func litPath(center: CGPoint, radius: CGFloat) -> Path {
        let k = min(max(illuminatedFraction, 0), 1)
        let half = radius * abs(1 - 2 * k)
        let sign: CGFloat = k < 0.5 ? 1 : -1     // crescent bulges toward the lit side
        let side: CGFloat = litOnRight ? 1 : -1
        let steps = 90

        var path = Path()
        guard k > 0.001 else { return path }
        for step in 0...steps {
            let t = Double.pi * Double(step) / Double(steps)
            let point = CGPoint(x: center.x + side * radius * sin(t), y: center.y - radius * cos(t))
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        for step in 0...steps {
            let t = Double.pi * Double(steps - step) / Double(steps)
            path.addLine(to: CGPoint(x: center.x + side * sign * half * sin(t), y: center.y - radius * cos(t)))
        }
        path.closeSubpath()
        return path
    }

    /// Fixed offsets and sizes as fractions of the radius — a few maria and craters, not a map.
    private static let craters: [(x: Double, y: Double, radius: Double)] = [
        (-0.35, -0.30, 0.20), (0.25, -0.45, 0.13), (0.40, 0.10, 0.18),
        (-0.15, 0.30, 0.15), (-0.50, 0.15, 0.09), (0.10, 0.60, 0.10),
    ]
}

#Preview("All eight phases, both hemispheres") {
    let phases: [(String, Double, Bool)] = [
        ("New", 0.0, true), ("Waxing crescent", 0.25, true), ("First quarter", 0.5, true),
        ("Waxing gibbous", 0.8, true), ("Full", 1.0, true), ("Waning gibbous", 0.8, false),
        ("Last quarter", 0.5, false), ("Waning crescent", 0.25, false),
    ]
    return ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ForEach([MoonHemisphere.northern, .southern], id: \.self) { hemisphere in
                Text(verbatim: hemisphere == .northern ? "Northern" : "Southern").foregroundStyle(.white)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(phases, id: \.0) { name, fraction, waxing in
                        VStack {
                            MoonView(illuminatedFraction: fraction, isWaxing: waxing,
                                     hemisphere: hemisphere, accessibilityText: name)
                                .frame(width: 70, height: 70)
                            Text(verbatim: name).font(.caption2).foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding()
    }
    .background(.black)
    .environment(\.theme, .fallback)
}
