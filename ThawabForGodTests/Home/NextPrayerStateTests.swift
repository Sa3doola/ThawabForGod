//
//  NextPrayerStateTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The card's rules, without a card: which entry is highlighted, which are behind us, and how
/// full the bar between two prayers is.
struct NextPrayerStateTests {

    private let today = PrayerTimeFixtures.day(2026, 6, 15)

    /// fajr 05:00 · sunrise 06:30 · dhuhr 12:00 · asr 15:30 · maghrib 18:00 · isha 19:30
    private func state(
        current: Prayer?,
        upcoming: Prayer,
        isTomorrow: Bool = false,
        previous: Prayer?,
        isYesterday: Bool = false
    ) -> NextPrayerState {
        let schedule = PrayerTimeFixtures.schedule(on: today)

        let upcomingDate = isTomorrow
            ? PrayerTimeFixtures.instant(today, hour: 29) // 05:00 tomorrow
            : schedule.time(for: upcoming)!

        let previousTime = previous.map { prayer in
            PrayerTime(
                prayer: prayer,
                date: isYesterday
                    ? PrayerTimeFixtures.instant(today, hour: -4, minute: -30) // 19:30 yesterday
                    : schedule.time(for: prayer)!
            )
        }

        return NextPrayerState(
            schedule: schedule,
            currentPrayer: current,
            upcoming: UpcomingPrayer(
                time: PrayerTime(prayer: upcoming, date: upcomingDate),
                isTomorrow: isTomorrow
            ),
            previous: previousTime.map { PassedPrayer(time: $0, isYesterday: isYesterday) }
        )
    }

    // MARK: Which entry is which

    @Test func theEntriesUpToAndIncludingTheCurrentOneHavePassed() {
        let subject = state(current: .dhuhr, upcoming: .asr, previous: .dhuhr)

        #expect(subject.hasPassed(.fajr))
        #expect(subject.hasPassed(.sunrise))
        #expect(subject.hasPassed(.dhuhr))
        #expect(subject.hasPassed(.asr) == false)
        #expect(subject.hasPassed(.isha) == false)
    }

    /// Before the day's Fajr the current prayer is yesterday's Isha, which this schedule cannot
    /// speak to — so nothing on it has passed.
    @Test func beforeFajrNothingHasPassed() {
        let subject = state(current: nil, upcoming: .fajr, previous: .isha, isYesterday: true)

        #expect(Prayer.allCases.allSatisfy { subject.hasPassed($0) == false })
    }

    @Test func theUpcomingEntryIsTheOneBeingCountedDownTo() {
        let subject = state(current: .dhuhr, upcoming: .asr, previous: .dhuhr)

        #expect(subject.isUpcoming(.asr))
        #expect(subject.isUpcoming(.maghrib) == false)
        #expect(subject.isCurrent(.dhuhr))
    }

    /// After Isha the countdown says "Fajr", but *today's* Fajr entry is long past — highlighting
    /// it would say the day is about to start rather than about to end.
    @Test func tomorrowsFajrHighlightsNothingOnTodaysRow() {
        let subject = state(
            current: .isha,
            upcoming: .fajr,
            isTomorrow: true,
            previous: .isha
        )

        #expect(subject.isUpcoming(.fajr) == false)
        #expect(Prayer.allCases.allSatisfy { subject.hasPassed($0) })
    }

    // MARK: The progress bar

    @Test func theBarFillsAcrossTheWindowBetweenTwoPrayers() {
        // Dhuhr 12:00 → Asr 15:30 is three and a half hours.
        let subject = state(current: .dhuhr, upcoming: .asr, previous: .dhuhr)

        #expect(subject.windowDuration == 3.5 * 3600)
        #expect(subject.progress(remaining: 3.5 * 3600) == 0)
        #expect(subject.progress(remaining: 1.75 * 3600) == 0.5)
        #expect(subject.progress(remaining: 0) == 1)
    }

    /// The hours before Fajr are the case the near end needs a second day's times for — and the
    /// bar has to be right there too, not merely not-crash.
    @Test func theWindowBeforeFajrReachesBackIntoYesterday() {
        // Isha 19:30 yesterday → Fajr 05:00 today is nine and a half hours.
        let subject = state(current: nil, upcoming: .fajr, previous: .isha, isYesterday: true)

        #expect(subject.windowDuration == 9.5 * 3600)
    }

    @Test func aReadingOutsideTheWindowIsClamped() {
        let subject = state(current: .dhuhr, upcoming: .asr, previous: .dhuhr)

        #expect(subject.progress(remaining: 99 * 3600) == 0)
        #expect(subject.progress(remaining: -60) == 1)
    }

    /// The anchor is decoration, and decoration that could not be resolved must not become a bar
    /// drawn from nowhere.
    @Test func withoutANearEndTheBarIsEmptyRatherThanWrong() {
        let subject = state(current: .dhuhr, upcoming: .asr, previous: nil)

        #expect(subject.windowDuration == nil)
        #expect(subject.progress(remaining: 60) == 0)
    }
}
