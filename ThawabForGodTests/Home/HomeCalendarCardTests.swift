//
//  HomeCalendarCardTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// How the Islamic calendar section reaches a Home screen, for the two kinds of reader: one who
/// never customized Home (derived from the defaults) and one who did (a stored layout, written by
/// a build in which the section did not exist yet).
struct HomeCalendarCardTests {

    private func decode(_ json: String) throws -> HomeLayout {
        try JSONDecoder().decode(HomeLayout.self, from: Data(json.utf8))
    }

    private func stored(_ pairs: [(String, Bool)]) -> String {
        let entries = pairs.map { #"{"kind":"\#($0.0)","isVisible":\#($0.1)}"# }.joined(separator: ",")
        return #"{"sections":[\#(entries)],"shortcuts":[]}"#
    }

    // MARK: Never customized

    @Test func aNeverCustomizedHomeShowsTheCalendarCard() {
        let repository = HomeLayoutRepository(settingsStore: InMemorySettingsStore())

        #expect(repository.layout().visibleSections.contains(.islamicCalendar))
        #expect(HomeLayout.default.visibleSections.contains(.islamicCalendar))
    }

    @Test func theCalendarCardComesAfterTheTrackerInDeclarationOrder() {
        let visible = HomeLayout.default.visibleSections

        #expect(visible == [.nextPrayer, .shortcuts, .continueReading, .lastActivity, .prayerTracker, .islamicCalendar])
    }

    // MARK: Customized before it existed

    @Test func aStoredLayoutThatHidesItKeepsItHidden() throws {
        let layout = try decode(stored([
            ("nextPrayer", true), ("shortcuts", true), ("continueReading", true),
            ("lastActivity", true), ("prayerTracker", true), ("islamicCalendar", false),
        ]))

        #expect(!layout.visibleSections.contains(.islamicCalendar))
        #expect(!layout.isVisible(HomeSectionKind.islamicCalendar))
        // ... but it is on offer in the editor, for the reader to switch on.
        #expect(layout.editableSections.map(\.kind).contains(.islamicCalendar))
        #expect(layout.canChangeVisibility(of: HomeSectionKind.islamicCalendar))
    }

    @Test func aHiddenCalendarStillLeavesTheThreeSectionFloorIntact() throws {
        // Everything but the pinned card hidden, as a reader who stripped Home down would have it.
        let layout = try decode(stored([
            ("nextPrayer", true), ("shortcuts", false), ("continueReading", false),
            ("lastActivity", false), ("prayerTracker", false), ("islamicCalendar", false),
        ]))

        #expect(layout.visibleSections.count >= HomeLayout.minimumVisibleSections)
        // The floor is restored in declaration order, so the calendar — last — is not conscripted.
        #expect(layout.visibleSections == [.nextPrayer, .shortcuts, .continueReading])
        #expect(!layout.isVisible(HomeSectionKind.islamicCalendar))
    }

    @Test func aStoredLayoutNeverHeardOfItGetsItAppendedVisible() throws {
        let layout = try decode(stored([("nextPrayer", true), ("shortcuts", true), ("continueReading", true)]))

        #expect(layout.visibleSections.contains(.islamicCalendar))
    }

    // MARK: The shortcut

    @Test func theCalendarShortcutIsInTheDefaultSetAndOpensTheCalendar() {
        let layout = HomeLayout.default

        #expect(layout.visibleShortcuts.contains(.islamicCalendar))
        #expect(layout.visibleShortcuts.count <= HomeLayout.maximumVisibleShortcuts)
        #expect(HomeShortcut.islamicCalendar.route == .hijriCalendar(selecting: nil))
    }

    @Test func aStoredShortcutSetThatHidesTheCalendarKeepsItHidden() throws {
        let json = #"{"sections":[],"shortcuts":[{"shortcut":"morningAdhkar","isVisible":true},{"shortcut":"islamicCalendar","isVisible":false}]}"#
        let layout = try decode(json)

        #expect(!layout.visibleShortcuts.contains(.islamicCalendar))
    }
}

@MainActor
struct HomeCardOccasionTests {

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private func model(on day: Date) -> HijriCalendarViewModel {
        let months = HijriCalendarService(timeZone: .gmt)
        return HijriCalendarViewModel(
            calendar: months,
            occasions: ResolveOccasionDatesUseCase(repository: BundledOccasionsRepository(), calendar: months),
            moon: GetMoonInfoUseCase(
                moon: AstronomicalMoonCalculator(),
                schedule: GetPrayerScheduleUseCase(repository: PrayerTimeRepository(engine: PrayerTimeEngine()))
            ),
            hijriDates: HijriDateService(timeZone: .gmt),
            settingsStore: InMemorySettingsStore(),
            coordinates: { .makkah },
            config: { .default },
            clock: TestClock(day.addingTimeInterval(12 * 3600)),
            timeZone: .gmt,
            locale: Locale(identifier: "en_US")
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Self.gregorian.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func anOccasionTodayIsAlwaysShown() {
        // 5 July 2025 is 10 Muharram 1447, Ashura.
        #expect(model(on: date(2025, 7, 5)).cardOccasion(lookAheadDays: 7) == .today(ashura))
    }

    @Test func theNextOccasionIsShownOnlyWithinAWeek() {
        // Two days before Ashura begins.
        if case .upcoming(let occasion, let days) = model(on: date(2025, 7, 2)).cardOccasion(lookAheadDays: 7) {
            #expect(occasion.id == "ashura")
            #expect(days == 2)
        } else {
            Issue.record("expected the upcoming Ashura")
        }

        // 10 July: the next once-a-year occasion is months away.
        #expect(model(on: date(2025, 7, 10)).cardOccasion(lookAheadDays: 7) == nil)
    }

    private var ashura: IslamicOccasion {
        BundledOccasionsRepository().occasions().first { $0.id == "ashura" }!
    }
}
