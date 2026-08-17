//
//  GetQiblaInfoUseCaseTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// These run against the real Adhan library and the real `CLLocation` geodesic — they are the
/// check that the two halves of a `QiblaInfo` are actually right, which no stub can tell us.
struct GetQiblaInfoUseCaseTests {

    private let useCase = GreatCircleQiblaInfoUseCase(engine: PrayerTimeEngine())

    private let london = Coordinates(latitude: 51.5074, longitude: -0.1278)

    @Test func itCarriesThePositionItWasAskedAbout() {
        #expect(useCase.qiblaInfo(for: london).coordinates == london)
    }

    /// The bearing comes straight from the engine, so this asserts the wiring rather than the
    /// astronomy — `PrayerTimeEngineTests` pins the numbers themselves.
    @Test func theDirectionIsTheEnginesBearing() {
        let engine = PrayerTimeEngine()

        #expect(useCase.qiblaInfo(for: london).direction == engine.qiblaBearing(from: london))
    }

    /// London to the Kaaba is a shade under 4,800 km. The tolerance covers the gap between the
    /// spherical figure most sources quote and the WGS-84 ellipsoid `CLLocation` measures on;
    /// it is nowhere near wide enough to hide a swapped latitude and longitude, which would put
    /// the answer thousands of kilometres out.
    @Test func theDistanceToTheKaabaIsTheGreatCircleOne() {
        let distance = useCase.qiblaInfo(for: london).distanceToKaaba

        #expect(abs(distance - 4_793_772) < 30_000)
    }

    @Test func newYorkIsAboutTenThousandKilometresOut() {
        let newYork = Coordinates(latitude: 40.7128, longitude: -74.0059)
        let distance = useCase.qiblaInfo(for: newYork).distanceToKaaba

        #expect(abs(distance - 10_306_296) < 60_000)
    }

    /// Degenerate, and worth pinning: at the Kaaba the distance collapses to nothing rather
    /// than to a NaN.
    @Test func theDistanceFromTheKaabaToItselfIsZero() {
        let distance = useCase.qiblaInfo(for: .makkah).distanceToKaaba

        #expect(distance < 100)
    }
}
