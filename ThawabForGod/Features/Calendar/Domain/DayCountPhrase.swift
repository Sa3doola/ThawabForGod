//
//  DayCountPhrase.swift
//  ThawabForGod
//

import Foundation

/// Which wording a count of days takes. Arabic changes the noun with the number — يوم واحد,
/// يومين, ٣ أيام, ١١ يومًا — so one catalogue string cannot serve every count, and English is
/// content with "1 day" and "N days".
nonisolated enum DayCountPhrase {

    static func key(for days: Int, isArabic: Bool) -> L10nKey {
        switch days {
        case 1: return .dayCountOne
        case 2: return .dayCountTwo
        default:
            guard isArabic else { return .dayCountFew }
            return (0...10).contains(days) ? .dayCountFew : .dayCountMany
        }
    }
}

/// `9–10 Muharram 1447` for a range inside one month, the two full dates for one that crosses a
/// month, and the plain date for a single day.
nonisolated enum OccasionDateText {

    static func hijri(
        first: HijriDate,
        last: HijriDate,
        localized: (L10nKey) -> String,
        number: (Int, Bool) -> String
    ) -> String {
        func full(_ date: HijriDate) -> String {
            HijriDateText.string(for: date, localized: localized, number: number)
        }
        guard first != last else { return full(first) }
        guard first.month == last.month, first.year == last.year else {
            return "\(full(first)) – \(full(last))"
        }
        return "\(number(first.day, true))–\(number(last.day, true)) \(localized(first.month.labelKey)) \(number(first.year, false))"
    }
}
