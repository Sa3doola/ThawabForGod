//
//  WidgetPrayerListTests.swift
//  ThawabForGodTests
//

import Testing
@testable import ThawabForGod

/// The rule the widgets' `PrayerList` is built on.
///
/// The view itself lives in the extension and cannot be imported here — that is the same wall
/// `NextPrayerTimelineTests` was written to get around. What *can* be pinned is the predicate the
/// view filters on, and it is the part with a decision in it: the All Prayers widget shows five
/// rows rather than six because Sunrise is not a prayer, and if `isObligatory` ever came to mean
/// something else the widget would quietly grow a row.
@MainActor
struct WidgetPrayerListTests {

    @Test func theDayHasFiveObligatoryPrayers() {
        #expect(Prayer.allCases.filter(\.isObligatory).count == 5)
    }

    @Test func sunriseIsTheOnlyMarkerLeftOut() {
        #expect(Prayer.allCases.filter { !$0.isObligatory } == [.sunrise])
    }

    /// Filtering must not reorder: the list is drawn top to bottom in the order it comes back, and
    /// `allCases` is chronological by declaration.
    @Test func theFiveStayInTheOrderOfTheDay() {
        #expect(
            Prayer.allCases.filter(\.isObligatory) == [.fajr, .dhuhr, .asr, .maghrib, .isha]
        )
    }
}
