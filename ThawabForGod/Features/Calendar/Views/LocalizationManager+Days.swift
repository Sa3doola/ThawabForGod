//
//  LocalizationManager+Days.swift
//  ThawabForGod
//

import Foundation

extension LocalizationManager {

    /// `1 day`, `2 days`, `٣ أيام` — in the language's own plural shape and the reader's digits.
    func dayCountString(_ days: Int) -> String {
        string(DayCountPhrase.key(for: days, isArabic: language.isRightToLeft), string(days))
    }

    /// `Today`, `Tomorrow`, `In 5 days`.
    func daysAwayString(_ days: Int) -> String {
        switch days {
        case ..<0: string(.occasionHappeningNow)
        case 0: string(.calendarToday)
        case 1: string(.occasionTomorrow)
        default: string(.inDayCount, dayCountString(days))
        }
    }
}
