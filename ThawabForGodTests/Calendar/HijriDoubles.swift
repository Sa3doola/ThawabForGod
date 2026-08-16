//
//  HijriDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// Answers with whatever the test prepared, ignoring the date it is handed.
///
/// A stub rather than a fake calendar: what the view model is responsible for is passing the
/// service's answers through to the screen, and `HijriDateServiceTests` already covers whether
/// those answers are right.
nonisolated struct StubHijriDateService: HijriDateServicing {
    var hijriDate = HijriDate(day: 1, month: .muharram, year: 1447)
    var events: [IslamicEvent] = []

    func hijriComponents(for date: Date) -> HijriDate {
        hijriDate
    }

    func islamicEvents(on date: Date) -> [IslamicEvent] {
        events
    }
}

extension IslamicEvent {
    /// A stand-in event, so tests do not have to depend on what the bundled table happens to
    /// contain today.
    static func stub(
        id: String = "test_event",
        nameKey: L10nKey = .eventAshura,
        noteKey: L10nKey? = nil,
        month: HijriMonth = .muharram,
        day: Int = 10
    ) -> IslamicEvent {
        IslamicEvent(id: id, nameKey: nameKey, noteKey: noteKey, month: month, day: day)
    }
}
