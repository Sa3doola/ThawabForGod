//
//  AstronomicalMoonCalculatorTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct AstronomicalMoonCalculatorTests {

    private let calculator = AstronomicalMoonCalculator()

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        Self.gregorian.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    // MARK: Known events (new 2026-10-10 15:50 UTC, full 2026-10-26 04:12 UTC — Star Walk /
    // TheSkyLive / Old Farmer's Almanac agree)

    @Test func newMoonOctober2026() {
        let found = calculator.nextNewMoon(after: utc(2026, 10, 3))
        #expect(abs(found.timeIntervalSince(utc(2026, 10, 10, 15, 50))) < 3600)
    }

    @Test func fullMoonOctober2026() {
        let found = calculator.nextFullMoon(after: utc(2026, 10, 18))
        #expect(abs(found.timeIntervalSince(utc(2026, 10, 26, 4, 12))) < 3600)
    }

    @Test func lastNewMoonLooksBackwards() {
        let found = calculator.lastNewMoon(onOrBefore: utc(2026, 10, 21))
        #expect(abs(found.timeIntervalSince(utc(2026, 10, 10, 15, 50))) < 3600)
    }

    // MARK: A named evening

    @Test func october21IsAWaxingGibbousNearSeventyNinePercent() {
        // Maghrib in Makkah, roughly 15:00 UTC.
        let info = calculator.info(at: utc(2026, 10, 21, 15))
        #expect((0.77...0.81).contains(info.illuminatedFraction))
        #expect((389_000...394_500).contains(info.distanceKm))
        #expect(info.phase == .waxingGibbous)
        #expect(info.isWaxing)
    }

    // MARK: Invariants over two years

    @Test func sweepStaysInRange() {
        var date = utc(2025, 1, 1)
        let end = utc(2027, 1, 1)
        while date < end {
            let info = calculator.info(at: date)
            #expect((356_000...407_000).contains(info.distanceKm))
            #expect((0...1).contains(info.illuminatedFraction))
            #expect((0..<360).contains(info.elongationDegrees))
            #expect((0...29.9).contains(info.ageInDays))
            #expect(info.isWaxing == (info.elongationDegrees < 180))
            date.addTimeInterval(6 * 3600)
        }
    }

    @Test func ageGrowsWithinACycle() {
        var previous = -1.0
        var date = utc(2026, 10, 10, 18)
        for _ in 0..<(28 * 4) {
            let age = calculator.info(at: date).ageInDays
            #expect(age > previous)
            previous = age
            date.addTimeInterval(6 * 3600)
        }
    }

    @Test func waxingFlipsAtFullAndNew() {
        let full = calculator.nextFullMoon(after: utc(2026, 10, 18))
        #expect(calculator.info(at: full.addingTimeInterval(-600)).isWaxing)
        #expect(!calculator.info(at: full.addingTimeInterval(600)).isWaxing)
        let new = calculator.nextNewMoon(after: utc(2026, 10, 18))
        #expect(!calculator.info(at: new.addingTimeInterval(-600)).isWaxing)
        #expect(calculator.info(at: new.addingTimeInterval(600)).isWaxing)
    }

    // MARK: Naming

    @Test(arguments: [
        (0.0, MoonPhase.newMoon), (22.4, .newMoon), (22.6, .waxingCrescent), (45, .waxingCrescent),
        (67.4, .waxingCrescent), (67.6, .firstQuarter), (90, .firstQuarter), (112.6, .waxingGibbous),
        (157.4, .waxingGibbous), (157.6, .fullMoon), (180, .fullMoon), (202.6, .waningGibbous),
        (247.6, .lastQuarter), (292.6, .waningCrescent), (337.4, .waningCrescent), (337.6, .newMoon),
        (359.9, .newMoon),
    ])
    func wedgesAreCenteredOnMultiplesOf45(elongation: Double, phase: MoonPhase) {
        #expect(MoonPhase(elongationDegrees: elongation) == phase)
    }
}
