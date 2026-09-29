//
//  DayRampBackground.swift
//  ThawabForGod
//

import SwiftUI

nonisolated extension RampChannel {
    /// The one place a ramp channel becomes a colour. `.sRGB` explicitly, because the values are
    /// the design's hexes and a hex is an sRGB triple — letting SwiftUI pick the space would
    /// leave the app's amber a slightly different amber from the canvas's.
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }
}

/// The surface behind the next-prayer card, the widget and the menu-bar popover's head: the
/// day's light, tiled with the motif.
///
/// Three layers and no more, because all three have to survive being drawn by a widget extension
/// inside WidgetKit's memory budget and by a `Canvas`-free SwiftUI on macOS 15:
///
/// 1. the ramp itself, as a plain `LinearGradient` — no custom pipeline, per the design;
/// 2. the girih lattice, weighted to the stop underneath it — see `DayRampStop.latticeOpacity`
///    for why that is a function and not the design's single number;
/// 3. one soft glow near the top trailing corner — the sun, in the same place in every stop, so
///    the card looks like the same object at Fajr and at Isha rather than a different drawing.
///
/// The glow sits at the *trailing* corner rather than the right, so it mirrors with the layout:
/// the Arabic build reads from the right and the light has to come from where the reading starts.
struct DayRampBackground: View {
    let stop: DayRampStop

    /// The glow sits at the trailing corner, so it has to mirror. `offset` is in absolute
    /// points and does not flip on its own — this is what flips it.
    @Environment(\.layoutDirection) private var layoutDirection

    /// The lattice is laid at a fixed size in points and never scaled with the card, so a small
    /// widget and a full-width phone card show the same tile at the same pitch.
    private let latticeSpacing: CGFloat = 26

    var body: some View {
        LinearGradient(
            colors: [stop.top.color, stop.bottom.color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            sun
        }
        // The lattice and the glow are both drawn past the edges; the card's own shape is what
        // decides where they stop.
        .clipped()
    }


    private var sun: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [DayRamp.Ink.lattice.color.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 55
                    )
                )
                .frame(width: 110, height: 110)
        }
        .allowsHitTesting(false)
    }
}

#Preview("Day ramp") {
    VStack(spacing: 12) {
        ForEach(Prayer.allCases) { prayer in
            DayRampBackground(stop: DayRamp.stop(for: prayer))
                .frame(height: 96)
                .clipShape(.rect(cornerRadius: AppRadius.lg))
                .overlay(alignment: .bottomLeading) {
                    Text(prayer.rawValue.capitalized)
                        .font(.headline)
                        .foregroundStyle(DayRamp.Ink.primary.color)
                        .padding(AppSpacing.md)
                }
                
        }
    }
    .padding()
}
