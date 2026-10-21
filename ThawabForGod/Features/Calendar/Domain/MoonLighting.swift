//
//  MoonLighting.swift
//  ThawabForGod
//

import Foundation

/// Where the Sun is, as seen from the Moon, in the *camera's* frame: x to the right, y up, z
/// toward the viewer. A unit vector pointing at the Sun.
nonisolated struct SunDirection: Equatable, Sendable {
    let x: Double
    let y: Double
    let z: Double
}

/// The lighting of the 3D moon, as pure functions of the phase.
///
/// The Moon is lit from wherever the Sun is, and the phase *is* that angle: the elongation is how
/// far the Moon is from the Sun in the sky, so the Sun sits that far round the Moon from the
/// viewer. Fixed to the camera rather than to the world, so a reader who spins the Moon turns the
/// surface under a light that stays where the phase says it is.
///
///     elongation   0°  new moon        sun behind the Moon   (0, 0, −1)
///                 90°  first quarter   sun on the right      (1, 0,  0)
///                180°  full moon        sun at the camera     (0, 0,  1)
///                270°  last quarter    sun on the left       (−1, 0, 0)
///
/// **The southern hemisphere sees the same Moon turned half a revolution**, which is what
/// `MoonView` does with the photograph: the lit side swaps and the face is upside down. So the
/// light's x is mirrored here and `viewRollDegrees` is what turns the Moon itself. Layout
/// direction appears nowhere — the Moon's lit side is physics, not reading order.
nonisolated enum MoonLighting {

    /// How much of the unlit side still shows — earthshine, the same figure `MoonView` uses.
    static let earthshine = 0.08

    static func sunDirection(elongationDegrees: Double, hemisphere: MoonHemisphere) -> SunDirection {
        let radians = elongationDegrees * .pi / 180
        let side = hemisphere == .southern ? -1.0 : 1.0
        return SunDirection(x: side * sin(radians), y: 0, z: -cos(radians))
    }

    /// The roll that turns the Moon's face over for a southern viewer.
    static func viewRollDegrees(hemisphere: MoonHemisphere) -> Double {
        hemisphere == .southern ? 180 : 0
    }
}
