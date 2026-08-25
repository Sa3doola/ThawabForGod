//
//  DayRampTests.swift
//  ThawabForGodTests
//

import Testing
@testable import ThawabForGod

/// The arithmetic behind the day's light.
///
/// Worth a suite of its own because the ramp is the one part of the design system that is a
/// *function* rather than a lookup, and because the fraction it takes is computed from a
/// countdown — a value that can be momentarily out of range at exactly the moment a prayer
/// arrives, which is the moment somebody is looking at the card.
struct DayRampTests {

    @Test func everyMarkerHasALightOfItsOwn() {
        let stops = Prayer.allCases.map(DayRamp.stop(for:))
        let distinct = Set(stops.map { "\($0.top)\($0.bottom)" })

        #expect(distinct.count == Prayer.allCases.count)
    }

    /// The ends of the blend are the stops themselves. Without this a rounding error in the mix
    /// would leave the card a shade off its own colour at the instant a prayer arrives.
    @Test func theEndsOfTheBlendAreTheStopsThemselves() {
        let start = DayRamp.stop(from: .fajr, to: .dhuhr, elapsed: 0)
        let end = DayRamp.stop(from: .fajr, to: .dhuhr, elapsed: 1)

        #expect(start == DayRamp.stop(for: .fajr))
        #expect(end == DayRamp.stop(for: .dhuhr))
    }

    /// A countdown can read a shade past its own boundary between a prayer arriving and the
    /// schedule being rebuilt, which makes the fraction negative — or, the other way, greater
    /// than one. Either would run the mix off the end of the day.
    @Test(arguments: [-3.0, -0.001, 1.001, 40.0])
    func aFractionOutsideTheDayIsClampedToIt(elapsed: Double) {
        let stop = DayRamp.stop(from: .maghrib, to: .isha, elapsed: elapsed)

        #expect(stop == DayRamp.stop(for: elapsed < 0 ? .maghrib : .isha))
    }

    @Test func halfwayThroughAWindowIsHalfwayBetweenItsTwoLights() {
        let stop = DayRamp.stop(from: .fajr, to: .sunrise, elapsed: 0.5)
        let fajr = DayRamp.stop(for: .fajr)
        let sunrise = DayRamp.stop(for: .sunrise)

        #expect(abs(stop.top.red - (fajr.top.red + sunrise.top.red) / 2) < 0.0001)
        #expect(abs(stop.bottom.blue - (fajr.bottom.blue + sunrise.bottom.blue) / 2) < 0.0001)
    }

    /// The design writes its colours as hexes, so the channel type has to read one the same way
    /// a browser would — anything else and the app's amber is a different amber from the canvas's.
    @Test func aPackedHexIsReadAsThreeChannels() {
        let white = RampChannel(0xFFFFFF)
        #expect(white.red == 1 && white.green == 1 && white.blue == 1)

        let black = RampChannel(0x000000)
        #expect(black.red == 0 && black.green == 0 && black.blue == 0)

        // Fajr's near end, which is the value the canvas prints.
        let fajr = RampChannel(0x1F2736)
        #expect(abs(fajr.red - 31.0 / 255) < 0.0001)
        #expect(abs(fajr.green - 39.0 / 255) < 0.0001)
        #expect(abs(fajr.blue - 54.0 / 255) < 0.0001)
    }
}

/// The lattice's weight against its ground, which is the one number in the design system that
/// had to become a function to survive being drawn at six different times of day.
struct DayRampLatticeTests {

    @Test func aBrighterGroundTakesLessLattice() {
        let dhuhr = DayRamp.stop(for: .dhuhr).latticeOpacity
        let isha = DayRamp.stop(for: .isha).latticeOpacity

        #expect(dhuhr < isha)
    }

    @Test func everyMarkerStaysInsideTheReadableBand() {
        for prayer in Prayer.allCases {
            let opacity = DayRamp.stop(for: prayer).latticeOpacity
            #expect(opacity >= 0.10 && opacity <= 0.30)
        }
    }

    /// The extremes clamp rather than run off either end — a stop is only ever the six above
    /// today, but the blend between two of them is a continuum and nothing stops a later marker
    /// being added at white or at black.
    @Test func theExtremesAreClamped() {
        let white = DayRampStop(top: RampChannel(0xFFFFFF), bottom: RampChannel(0xFFFFFF))
        let black = DayRampStop(top: RampChannel(0x000000), bottom: RampChannel(0x000000))

        #expect(white.latticeOpacity == 0.10)
        #expect(black.latticeOpacity == 0.30)
    }
}
