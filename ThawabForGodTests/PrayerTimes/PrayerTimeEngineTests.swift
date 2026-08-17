//
//  PrayerTimeEngineTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// These run against the real Adhan library — they are the check that the mapping into and
/// out of it is right, which no mock can tell us.
struct PrayerTimeEngineTests {

    private let engine = PrayerTimeEngine(timeZone: .gmt)
    private let day = PrayerTimeFixtures.day(2026, 6, 15)

    @Test func aDayHasAllSixMarkersInChronologicalOrder() throws {
        let schedule = try engine.schedule(for: .makkah, date: day, config: .default)

        #expect(schedule.times.map(\.prayer) == Prayer.allCases)

        let dates = schedule.times.map(\.date)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
    }

    @Test func theScheduleIsStampedWithTheStartOfItsDay() throws {
        let schedule = try engine.schedule(
            for: .makkah,
            date: PrayerTimeFixtures.instant(day, hour: 17, minute: 42),
            config: .default
        )

        #expect(schedule.day == day)
    }

    /// Hanafi Asr is defined by a longer shadow, so it always falls later than Shafi's — the
    /// cheapest observable proof that the madhab is actually reaching the library.
    @Test func theHanafiMadhabPushesAsrLater() throws {
        let shafi = try engine.schedule(
            for: .makkah,
            date: day,
            config: CalculationConfig(method: .muslimWorldLeague, madhab: .shafi)
        )
        let hanafi = try engine.schedule(
            for: .makkah,
            date: day,
            config: CalculationConfig(method: .muslimWorldLeague, madhab: .hanafi)
        )

        let shafiAsr = try #require(shafi.time(for: .asr))
        let hanafiAsr = try #require(hanafi.time(for: .asr))

        #expect(hanafiAsr > shafiAsr)
    }

    /// Likewise for the method: Umm al-Qura fixes Isha at 90 minutes after Maghrib, which no
    /// other preset here does.
    @Test func theCalculationMethodReachesTheLibrary() throws {
        let schedule = try engine.schedule(
            for: .makkah,
            date: day,
            config: CalculationConfig(method: .ummAlQura, madhab: .shafi)
        )

        let maghrib = try #require(schedule.time(for: .maghrib))
        let isha = try #require(schedule.time(for: .isha))

        #expect(isha.timeIntervalSince(maghrib) == 90 * 60)
    }

    @Test func everyOfferedMethodResolves() throws {
        for method in PrayerCalculationMethod.allCases {
            let config = CalculationConfig(method: method, madhab: .shafi)
            let schedule = try engine.schedule(for: .makkah, date: day, config: config)

            #expect(schedule.times.count == 6, "\(method.rawValue) produced an incomplete day")
        }
    }

    /// The bearing is checked against Adhan's own published expectation for New York, so a
    /// regression in the mapping (swapped latitude and longitude, say) cannot slip through.
    @Test func theQiblaBearingMatchesTheKnownValueForNewYork() {
        let newYork = Coordinates(latitude: 40.7128, longitude: -74.0059)

        #expect(abs(engine.qiblaBearing(from: newYork) - 58.481) < 0.001)
    }

    /// A second published reference point, on a different meridian to New York, so a formula
    /// that happened to be right for one longitude cannot pass on its own.
    @Test func theQiblaBearingMatchesTheKnownValueForWashingtonDC() {
        let washington = Coordinates(latitude: 38.9072, longitude: -77.0369)

        #expect(abs(engine.qiblaBearing(from: washington) - 56.560) < 0.001)
    }

    @Test func theQiblaBearingFromMakkahPointsAtItself() {
        // Degenerate but worth pinning: the bearing must stay finite at the Kaaba itself.
        #expect(engine.qiblaBearing(from: .makkah).isFinite)
    }
}
