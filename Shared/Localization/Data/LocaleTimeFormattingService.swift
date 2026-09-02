//
//  LocaleTimeFormattingService.swift
//  ThawabForGod
//

import Foundation

/// `DateFormatter`-backed clock times, one formatter per language/digit pairing.
///
/// Safety invariant for `@unchecked Sendable`: every formatter is fully configured in `init`
/// and never mutated afterwards. Foundation documents `DateFormatter` as safe for concurrent
/// *formatting* under exactly that condition. Building them once is worth the code — a
/// running countdown reformats a screenful of times every second.
nonisolated final class LocaleTimeFormattingService: TimeFormattingService, @unchecked Sendable {
    private struct Style: Hashable {
        let language: AppLanguage
        let system: NumberSystem
        let clock: ClockFormat
    }

    private let timeFormatters: [Style: DateFormatter]

    /// Calendar dates, which need no clock choice — four rather than twelve.
    private struct DateStyle: Hashable {
        let language: AppLanguage
        let system: NumberSystem
    }

    private let dateFormatters: [DateStyle: DateFormatter]

    /// The same four again, abbreviated and yearless — see `shortDateString(from:language:system:)`.
    private let shortDateFormatters: [DateStyle: DateFormatter]

    /// Very short weekday names, one formatter per language — the strip's seven letters.
    private let weekdayFormatters: [AppLanguage: DateFormatter]

    /// Two digits, zero-padded, per numbering system. Padding a countdown by hand would mean
    /// prepending a Latin `"0"` in front of Arabic-Indic digits.
    private let paddedFormatters: [NumberSystem: NumberFormatter]

    /// Leading component of a countdown — unpadded, so it reads `9:05`, not `09:05`.
    private let plainFormatters: [NumberSystem: NumberFormatter]

    init() {
        var times: [Style: DateFormatter] = [:]

        // Twelve formatters — two languages, two digit systems, three clock choices. Every
        // combination is reachable, and building them all here is what keeps a ticking
        // countdown from allocating one per second.
        for language in AppLanguage.allCases {
            for system in NumberSystem.allCases {
                for clock in ClockFormat.allCases {
                    let locale = Locale(
                        identifier: "\(language.rawValue)@numbers=\(system.numberingSystemTag)"
                    )

                    let formatter = DateFormatter()
                    formatter.locale = locale
                    // `autoupdatingCurrent`, not `current`: the app can outlive a flight, and
                    // prayer times are meaningless in the departure city's zone.
                    formatter.timeZone = .autoupdatingCurrent
                    // A template rather than a fixed pattern, so the order of the parts and
                    // the position of the AM/PM marker follow the locale even when the hour
                    // cycle is the user's choice rather than the region's.
                    formatter.setLocalizedDateFormatFromTemplate(clock.dateFormatTemplate)
                    times[Style(language: language, system: system, clock: clock)] = formatter
                }
            }
        }

        var dates: [DateStyle: DateFormatter] = [:]

        for language in AppLanguage.allCases {
            for system in NumberSystem.allCases {
                let formatter = DateFormatter()
                formatter.locale = Locale(
                    identifier: "\(language.rawValue)@numbers=\(system.numberingSystemTag)"
                )
                formatter.timeZone = .autoupdatingCurrent
                // Gregorian explicitly, not whatever the locale carries — see the protocol.
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.setLocalizedDateFormatFromTemplate("dMMMMy")
                dates[DateStyle(language: language, system: system)] = formatter
            }
        }

        var shortDates: [DateStyle: DateFormatter] = [:]

        for language in AppLanguage.allCases {
            for system in NumberSystem.allCases {
                let formatter = DateFormatter()
                formatter.locale = Locale(
                    identifier: "\(language.rawValue)@numbers=\(system.numberingSystemTag)"
                )
                formatter.timeZone = .autoupdatingCurrent
                formatter.calendar = Calendar(identifier: .gregorian)
                // `dMMM` — abbreviated month, no year. The template is what puts the day and the
                // month in the order the language wants, which is not the same in both.
                formatter.setLocalizedDateFormatFromTemplate("dMMM")
                shortDates[DateStyle(language: language, system: system)] = formatter
            }
        }

        var weekdays: [AppLanguage: DateFormatter] = [:]

        for language in AppLanguage.allCases {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: language.rawValue)
            formatter.timeZone = .autoupdatingCurrent
            formatter.calendar = Calendar(identifier: .gregorian)
            // `EEEEE` is the *narrow* weekday — one letter in English, one in Arabic. `EEE`
            // would be "Mon", which is three times the width the strip has for it.
            formatter.setLocalizedDateFormatFromTemplate("EEEEE")
            weekdays[language] = formatter
        }

        self.timeFormatters = times
        self.dateFormatters = dates
        self.shortDateFormatters = shortDates
        self.weekdayFormatters = weekdays
        self.paddedFormatters = Self.numberFormatters(minimumIntegerDigits: 2)
        self.plainFormatters = Self.numberFormatters(minimumIntegerDigits: 1)
    }

    private static func numberFormatters(minimumIntegerDigits: Int) -> [NumberSystem: NumberFormatter] {
        var formatters: [NumberSystem: NumberFormatter] = [:]

        for system in NumberSystem.allCases {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: system.localeIdentifier)
            formatter.numberStyle = .none
            formatter.minimumIntegerDigits = minimumIntegerDigits
            // A countdown is a clock reading, not a quantity: `1:05:00`, never `1:05:000`.
            formatter.usesGroupingSeparator = false
            formatters[system] = formatter
        }

        return formatters
    }

    func timeString(
        from date: Date,
        language: AppLanguage,
        system: NumberSystem,
        clock: ClockFormat
    ) -> String {
        let style = Style(language: language, system: system, clock: clock)
        guard let formatter = timeFormatters[style] else {
            return ""
        }
        return formatter.string(from: date)
    }

    func dateString(from date: Date, language: AppLanguage, system: NumberSystem) -> String {
        dateFormatters[DateStyle(language: language, system: system)]?.string(from: date) ?? ""
    }

    func shortDateString(from date: Date, language: AppLanguage, system: NumberSystem) -> String {
        shortDateFormatters[DateStyle(language: language, system: system)]?.string(from: date) ?? ""
    }

    func weekdayString(from date: Date, language: AppLanguage) -> String {
        weekdayFormatters[language]?.string(from: date) ?? ""
    }

    func countdownString(from interval: TimeInterval, system: NumberSystem) -> String {
        let total = Int(max(0, interval).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        // Below an hour the hours component is noise, so it is dropped and minutes lead.
        let components = hours > 0
            ? [plain(hours, system), padded(minutes, system), padded(seconds, system)]
            : [plain(minutes, system), padded(seconds, system)]

        return Self.isolatedLeftToRight(components.joined(separator: ":"))
    }

    func briefCountdownString(from interval: TimeInterval, system: NumberSystem) -> String {
        let total = Int(max(0, interval).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        // Above the hour the leading figure is hours and the second is minutes; inside it the
        // pair shifts down to minutes and seconds. Two components either way, which is what
        // holds the slot still — the transition happens once, at the boundary, and the label
        // narrows by at most one character when the hours figure was two digits.
        let components = hours > 0
            ? [plain(hours, system), padded(minutes, system)]
            : [plain(minutes, system), padded(seconds, system)]

        return Self.isolatedLeftToRight(components.joined(separator: ":"))
    }

    /// Wraps a clock reading so the bidirectional algorithm leaves its parts in order.
    ///
    /// Without this, `6:06:57` rendered inside an Arabic screen comes out as `٦:٠ ٦:٥٧` —
    /// two colons make the run ambiguous, and the surrounding right-to-left paragraph
    /// reorders the groups. A duration is read left to right in both languages, so it is
    /// isolated rather than left to inherit the paragraph's direction. The digits themselves
    /// are unaffected and still follow the user's choice.
    private static func isolatedLeftToRight(_ string: String) -> String {
        "\u{2066}\(string)\u{2069}" // LEFT-TO-RIGHT ISOLATE … POP DIRECTIONAL ISOLATE
    }

    private func plain(_ value: Int, _ system: NumberSystem) -> String {
        plainFormatters[system]?.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func padded(_ value: Int, _ system: NumberSystem) -> String {
        paddedFormatters[system]?.string(from: NSNumber(value: value)) ?? String(format: "%02d", value)
    }
}
