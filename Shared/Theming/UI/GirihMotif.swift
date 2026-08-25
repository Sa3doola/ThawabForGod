//
//  GirihMotif.swift
//  ThawabForGod
//

import SwiftUI

/// The eight-point girih star, as an outline.
///
/// One construction — a square and the same square turned through 45° — which is the whole motif
/// the app is built on. Stroking this path draws both outlines and so the star; filling it is not
/// what it is for and will read as a blot.
///
/// It is a `Shape` rather than an image so it inherits the stroke colour and scales to whatever
/// it is given: the same path is the verse marker at 30pt, the chapter ornament at 34pt, the
/// empty-state mark at 96pt and the app icon's arc at 1024.
nonisolated struct GirihStar: Shape {
    /// How far the star's points reach in from the edge of the box. Zero fills the box.
    var inset: CGFloat = 0

    nonisolated func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        var path = Path()
        path.addRect(box)

        // The second square is the first turned about the centre. Drawn as a transformed
        // sub-path rather than four computed corners, so the two can never drift apart.
        var turned = Path()
        turned.addRect(box)
        path.addPath(
            turned.applying(
                CGAffineTransform(translationX: box.midX, y: box.midY)
                    .rotated(by: .pi / 4)
                    .translatedBy(x: -box.midX, y: -box.midY)
            )
        )
        return path
    }
}

/// The girih lattice: the star's two axes, repeated across a surface.
///
/// A ground, never a subject. The design's rule is that it is drawn at 14% opacity behind a card
/// and never above 18% behind text, and it is **never rotated per instance** — the whole point of
/// a tiling is that two cards side by side are cut from the same cloth.
///
/// `spacing` is the perpendicular distance between neighbouring lines, which is what the eye
/// actually reads; the diagonal step is that times √2, computed here so no caller has to.
nonisolated struct GirihLattice: Shape {
    var spacing: CGFloat = 26

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        guard spacing > 0, rect.width > 0, rect.height > 0 else { return path }

        let step = spacing * 2.0.squareRoot()
        let height = rect.height

        // Both families run corner to corner, so each has to start a full height's worth to the
        // left of the box to cover the bottom-left corner and run a box's width past the right.
        var offset = rect.minX - height
        while offset <= rect.maxX + height {
            path.move(to: CGPoint(x: offset, y: rect.minY))
            path.addLine(to: CGPoint(x: offset + height, y: rect.maxY))

            path.move(to: CGPoint(x: offset, y: rect.minY))
            path.addLine(to: CGPoint(x: offset - height, y: rect.maxY))

            offset += step
        }
        return path
    }
}
