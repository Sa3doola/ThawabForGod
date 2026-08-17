//
//  CompassDial.swift
//  ThawabForGod
//

import SwiftUI

/// The live compass: a dial that turns with the device, and a needle that stays on the Kaaba.
///
/// Both rotations come from the same pair of angles, which is what keeps them honest — the
/// dial is turned by `-deviceHeading` so its north marker sits over true north, and the needle
/// by `needleRotation`, which is the bearing measured in the same turned frame.
struct CompassDial: View {
    let viewModel: QiblaViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    private let diameter: CGFloat = 260

    var body: some View {
        ZStack {
            dial
            QiblaNeedle()
                .fill(theme.accent)
                .frame(width: 34, height: diameter * 0.78)
                .rotationEffect(.degrees(viewModel.needleRotation))
        }
        .frame(width: diameter, height: diameter)
        // A compass is geometry, not text: mirroring it for Arabic would put north on the
        // wrong side of the dial and point the needle away from the Kaaba. The labels around
        // it still mirror — this pins the instrument alone.
        .environment(\.layoutDirection, .leftToRight)
        .animation(.easeOut(duration: 0.2), value: viewModel.needleRotation)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(.qiblaNeedleLabel))
        .accessibilityValue(l10n.degreesString(viewModel.qiblaDirection))
    }

    private var dial: some View {
        ZStack {
            Circle()
                .fill(theme.surface)
            Circle()
                .strokeBorder(theme.separator, lineWidth: 1)

            ForEach(0..<72, id: \.self) { index in
                // Every fifth mark — 25° apart is too coarse, so the ring is 72 marks and
                // every sixth is a major one, giving a labelled quarter at each cardinal.
                Capsule()
                    .fill(index.isMultiple(of: 6) ? theme.textSecondary : theme.separator)
                    .frame(width: 1.5, height: index.isMultiple(of: 6) ? 12 : 6)
                    .offset(y: -(diameter / 2) + 12)
                    .rotationEffect(.degrees(Double(index) * 5))
            }

            Text(l10n.string(.qiblaNorthMarker))
                .appFont(.footnote, weight: .bold)
                .foregroundStyle(theme.textSecondary)
                .offset(y: -(diameter / 2) + 30)
        }
        .rotationEffect(.degrees(-viewModel.deviceHeading))
    }
}

/// A slim arrow pointing at twelve o'clock, so a rotation of zero means "straight ahead".
private struct QiblaNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let headHeight = rect.height * 0.28

        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + headHeight))
        path.addLine(to: CGPoint(x: midX + rect.width * 0.14, y: rect.minY + headHeight))
        path.addLine(to: CGPoint(x: midX + rect.width * 0.14, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - rect.width * 0.14, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - rect.width * 0.14, y: rect.minY + headHeight))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + headHeight))
        path.closeSubpath()

        return path
    }
}
