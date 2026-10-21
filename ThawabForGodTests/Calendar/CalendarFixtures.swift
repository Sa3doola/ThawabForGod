//
//  CalendarFixtures.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

extension HijriCalendarViewModel {

    /// A calendar view model over the given store, reading the same offset the store holds — the
    /// way the container builds one — with the clock fixed at midday on 2 July 2025 (UTC).
    static func testing(
        store: InMemorySettingsStore = InMemorySettingsStore(),
        onOffsetChange: @escaping @MainActor () -> Void = {}
    ) -> HijriCalendarViewModel {
        let offset: @Sendable () -> Int = { HijriDayOffset.current(in: store) }
        let months = HijriCalendarService(timeZone: .gmt, dayOffset: offset)
        return HijriCalendarViewModel(
            calendar: months,
            occasions: ResolveOccasionDatesUseCase(
                repository: BundledOccasionsRepository(),
                calendar: months,
                dayOffset: offset
            ),
            moon: GetMoonInfoUseCase(
                moon: AstronomicalMoonCalculator(),
                schedule: GetPrayerScheduleUseCase(repository: PrayerTimeRepository(engine: PrayerTimeEngine()))
            ),
            hijriDates: HijriDateService(timeZone: .gmt, dayOffset: offset),
            settingsStore: store,
            coordinates: { .makkah },
            config: { .default },
            clock: TestClock(Date(timeIntervalSince1970: 1_751_457_600)),
            timeZone: .gmt,
            locale: Locale(identifier: "en_US"),
            onOffsetChange: onOffsetChange
        )
    }
}
