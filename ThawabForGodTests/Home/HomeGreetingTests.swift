//
//  HomeGreetingTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Three greetings and two boundaries, pinned so a refactor cannot quietly wish somebody good
/// morning at four in the afternoon.
struct HomeGreetingTests {

    private let day = PrayerTimeFixtures.day(2026, 6, 15)

    private func greeting(atHour hour: Int) -> HomeGreeting {
        HomeGreeting.at(
            PrayerTimeFixtures.instant(day, hour: hour),
            calendar: PrayerTimeFixtures.calendar
        )
    }

    @Test func theMorningRunsFromFiveUntilNoon() {
        #expect(greeting(atHour: 5) == .morning)
        #expect(greeting(atHour: 11) == .morning)
    }

    @Test func theAfternoonRunsFromNoonUntilFive() {
        #expect(greeting(atHour: 12) == .afternoon)
        #expect(greeting(atHour: 16) == .afternoon)
    }

    /// The evening takes the night with it, deliberately: somebody awake at two in the morning
    /// has just *opened* the app, and being wished good night is the wrong response to that.
    @Test func theEveningCoversTheNightAsWell() {
        #expect(greeting(atHour: 17) == .evening)
        #expect(greeting(atHour: 23) == .evening)
        #expect(greeting(atHour: 2) == .evening)
        #expect(greeting(atHour: 4) == .evening)
    }
}
