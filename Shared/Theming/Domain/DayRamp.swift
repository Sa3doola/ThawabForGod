//
//  DayRamp.swift
//  ThawabForGod
//

import Foundation

/// A colour, as three channels, with no `Color` in sight.
///
/// Domain does not import SwiftUI, and the ramp has to do arithmetic on colours — which is the
/// one thing `Color` will not let anyone do. So the mixing happens here on numbers and the
/// result is turned into a `Color` once, at the edge, in `Shared/Theming/UI`.
nonisolated struct RampChannel: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    /// From `0xRRGGBB`, which is how the design writes them and so how they are written here.
    init(_ packed: UInt32) {
        self.red = Double((packed >> 16) & 0xFF) / 255
        self.green = Double((packed >> 8) & 0xFF) / 255
        self.blue = Double(packed & 0xFF) / 255
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Blends two channels, clamped to the pair.
    ///
    /// The two ends return their own value rather than computing it. `a + (b - a) * 1` is `b`
    /// only up to a rounding error, and the ends of the blend are exactly where somebody is
    /// looking: the instant a prayer arrives is the instant the card must be that prayer's
    /// colour, not a shade beside it.
    static func mix(_ a: Self, _ b: Self, _ t: Double) -> Self {
        guard t > 0 else { return a }
        guard t < 1 else { return b }

        return Self(
            red: a.red + (b.red - a.red) * t,
            green: a.green + (b.green - a.green) * t,
            blue: a.blue + (b.blue - a.blue) * t
        )
    }
}

/// The two ends of one prayer's light.
nonisolated struct DayRampStop: Equatable, Sendable {
    var top: RampChannel
    var bottom: RampChannel

    static func mix(_ a: Self, _ b: Self, _ t: Double) -> Self {
        Self(
            top: .mix(a.top, b.top, t),
            bottom: .mix(a.bottom, b.bottom, t)
        )
    }

    /// How strongly the girih lattice is drawn over *this* stop.
    ///
    /// **Not a constant, and that is the point.** The design gives the lattice one number — 14%
    /// as a card ground — but it gives it against one card, drawn at Asr, on deep terracotta. The
    /// ramp is not one ground: Isha is near-black and Dhuhr is nearly gold, and a cream lattice
    /// that is a whisper on the first is a quilt on the second. Holding the opacity fixed would
    /// mean the motif is only correctly weighted at one hour of the day.
    ///
    /// So the ground decides. The brighter the stop, the less lattice, on a straight line from
    /// 30% over Isha to about 15% over Dhuhr — which is what makes the card look like the same
    /// object all day instead of a different one every three hours.
    ///
    /// The weighting is the usual perceptual one applied to the sRGB values rather than to
    /// linearised ones. That is not a correct luminance and does not need to be: what is wanted
    /// is "how light does this look", to pick an opacity, and the cheaper number answers it
    /// closely enough that no eye could pick the two apart.
    var latticeOpacity: Double {
        let lightness = 0.2126 * bottom.red + 0.7152 * bottom.green + 0.0722 * bottom.blue
        return min(max(0.30 - 0.20 * lightness, 0.10), 0.30)
    }
}

/// The arc of the day, as colour.
///
/// **This is not a token and must never be used as one.** The closed token set — Background,
/// Surface, Primary, TextPrimary, TextSecondary, Separator, Success, Warning, Danger, accent —
/// is what a view reads to draw a surface. The ramp is a *function of the time*, and it appears
/// in exactly three places: behind the next-prayer card, behind the widget, and behind the
/// menu-bar popover's header. Everywhere else the day is told in words and in the tokens.
///
/// It lives in Theming rather than beside `Prayer` because it is a decision about how the app
/// looks, not about when a prayer is; that it is keyed on `Prayer` is a Domain type naming
/// another Domain type in the same module, which costs no import and no dependency edge.
///
/// Text drawn on it is always the fixed on-ramp ink below — never `TextPrimary`, which follows
/// the appearance and would go black on Fajr's blue-grey the moment the user chose light mode.
nonisolated enum DayRamp {
    /// The light at each of the six markers.
    static func stop(for prayer: Prayer) -> DayRampStop {
        switch prayer {
        case .fajr: DayRampStop(top: RampChannel(0x1F2736), bottom: RampChannel(0x3E4C63))
        case .sunrise: DayRampStop(top: RampChannel(0x6E5A5E), bottom: RampChannel(0xC58B5A))
        case .dhuhr: DayRampStop(top: RampChannel(0xC98F43), bottom: RampChannel(0xE8B65C))
        case .asr: DayRampStop(top: RampChannel(0xB4682F), bottom: RampChannel(0xD99A4E))
        case .maghrib: DayRampStop(top: RampChannel(0x6B3A46), bottom: RampChannel(0xA85B45))
        case .isha: DayRampStop(top: RampChannel(0x12101C), bottom: RampChannel(0x2E2846))
        }
    }

    /// The light *now*: between the two markers that bracket this moment, by how much of the
    /// interval between them has gone.
    ///
    /// `elapsed` is a fraction, and it is clamped rather than trusted — the caller computes it
    /// from a countdown that can go momentarily negative between a prayer arriving and the
    /// schedule being rebuilt, and a negative fraction would run the mix off the end of the day.
    static func stop(from previous: Prayer, to next: Prayer, elapsed: Double) -> DayRampStop {
        .mix(stop(for: previous), stop(for: next), elapsed)
    }

    /// The ink drawn on the ramp, at three weights. Fixed values, not tokens: the ramp is dark at
    /// every hour of the day, so what sits on it never changes with the appearance.
    enum Ink {
        static let primary = RampChannel(0xFFFFFF)
        static let secondary = RampChannel(0xFFFFFF)
        static let secondaryOpacity: Double = 0.8
        static let kickerOpacity: Double = 0.72
        static let railOpacity: Double = 0.2
        static let railFill = RampChannel(0xFFF0D6)
        /// The lattice laid over the ramp. Warm, not white — the motif is meant to read as
        /// tilework catching the light rather than as a grid drawn on top of it.
        static let lattice = RampChannel(0xFFEBC8)
    }
}
