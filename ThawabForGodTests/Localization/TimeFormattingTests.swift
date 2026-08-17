//
//  TimeFormattingTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The point of this service is that digits are a *separate* choice from language, so most of
/// these check the combinations a single `Locale` could not express.
struct TimeFormattingTests {

    private let service = LocaleTimeFormattingService()

    /// Countdowns come back wrapped in directional isolates so an Arabic screen does not
    /// reorder `1:05:07` into `1:0 5:07`. Asserted on the reading inside the isolates, with
    /// their presence pinned separately below.
    private func countdown(_ interval: TimeInterval, _ system: NumberSystem) -> String {
        service.countdownString(from: interval, system: system)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{2066}\u{2069}"))
    }

    // MARK: Countdowns

    @Test func countdownsBelowAnHourDropTheHoursComponent() {
        #expect(countdown(90, .latin) == "1:30")
    }

    @Test func countdownsAboveAnHourPadMinutesAndSeconds() {
        #expect(countdown(3600 + 5 * 60 + 7, .latin) == "1:05:07")
    }

    @Test func countdownsTruncateRatherThanRound() {
        #expect(countdown(59.9, .latin) == "0:59")
    }

    @Test func negativeCountdownsClampToZero() {
        #expect(countdown(-10, .latin) == "0:00")
    }

    @Test func longCountdownsKeepTheHoursUnpadded() {
        #expect(countdown(9 * 3600, .latin) == "9:00:00")
    }

    @Test func countdownsFollowTheArabicIndicDigitChoice() {
        #expect(countdown(3600 + 5 * 60 + 7, .arabicIndic) == "١:٠٥:٠٧")
    }

    /// A countdown is a clock reading, not a quantity — no thousands separator may appear
    /// once the hours run past three digits.
    @Test func countdownsCarryNoGroupingSeparator() {
        #expect(countdown(1234 * 3600, .latin) == "1234:00:00")
    }

    /// The isolates themselves. Without them an Arabic screen reorders the h:mm:ss groups,
    /// which is a real rendering bug rather than a cosmetic one.
    @Test func countdownsAreIsolatedFromTheSurroundingTextDirection() {
        let formatted = service.countdownString(from: 3600 + 5 * 60 + 7, system: .arabicIndic)

        #expect(formatted.hasPrefix("\u{2066}"))
        #expect(formatted.hasSuffix("\u{2069}"))
    }

    // MARK: Clock times

    // Asserted on the digit *script* rather than on a particular reading. The service
    // formats in the device's time zone, which is exactly what it should do — so pinning
    // "5:42" here would only test where the machine running the suite happens to be.
    private let latinDigits = Set("0123456789")
    private let arabicIndicDigits = Set("٠١٢٣٤٥٦٧٨٩")

    private func digitsAreExclusively(
        _ expected: Set<Character>,
        _ other: Set<Character>,
        in string: String
    ) -> Bool {
        string.contains { expected.contains($0) } && !string.contains { other.contains($0) }
    }

    @Test func clockTimesFollowTheSelectedDigits() {
        let date = Date()

        let latin = service.timeString(from: date, language: .english, system: .latin, clock: .system)
        let arabicIndic = service.timeString(from: date, language: .english, system: .arabicIndic, clock: .system)

        #expect(digitsAreExclusively(latinDigits, arabicIndicDigits, in: latin))
        #expect(digitsAreExclusively(arabicIndicDigits, latinDigits, in: arabicIndic))
    }

    /// The combination that motivates the whole service: English wording, Arabic-Indic digits.
    /// A single `Locale` cannot express it, which is why `Text(date, style:)` will not do.
    @Test func languageAndDigitsAreIndependent() {
        let date = Date()

        let englishArabicDigits = service.timeString(from: date, language: .english, system: .arabicIndic, clock: .system)
        let arabicLatinDigits = service.timeString(from: date, language: .arabic, system: .latin, clock: .system)

        #expect(digitsAreExclusively(arabicIndicDigits, latinDigits, in: englishArabicDigits))
        #expect(digitsAreExclusively(latinDigits, arabicIndicDigits, in: arabicLatinDigits))
    }

    @Test func everyLanguageDigitAndClockPairingProducesATime() {
        let date = PrayerTimeFixtures.instant(PrayerTimeFixtures.day(2026, 6, 15), hour: 5, minute: 42)

        for language in AppLanguage.allCases {
            for system in NumberSystem.allCases {
                for clock in ClockFormat.allCases {
                    let formatted = service.timeString(
                        from: date,
                        language: language,
                        system: system,
                        clock: clock
                    )

                    #expect(
                        !formatted.isEmpty,
                        "\(language.rawValue)/\(system.rawValue)/\(clock.rawValue) produced nothing"
                    )
                }
            }
        }
    }

    // MARK: Clock format

    /// 17:05 in whatever zone the machine is in, so the assertions below hold wherever the suite
    /// runs — the service formats in the device's zone, which a UTC fixture would fight.
    private var lateAfternoon: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar.date(bySettingHour: 17, minute: 5, second: 0, of: Date())!
    }

    private func time(_ clock: ClockFormat, _ language: AppLanguage = .english) -> String {
        service.timeString(from: lateAfternoon, language: language, system: .latin, clock: clock)
    }

    @Test func theTwentyFourHourChoiceOverridesTheLocale() {
        #expect(time(.twentyFourHour).contains("17"))
    }

    /// The other half: the same instant, in the form the same locale might not have chosen.
    @Test func theTwelveHourChoiceOverridesTheLocale() {
        let formatted = time(.twelveHour)

        #expect(formatted.contains("5"))
        #expect(!formatted.contains("17"))
    }

    /// `.system` is not a third rendering — it is deferral. Whichever the locale picks, it has to
    /// match one of the two the user could have asked for.
    @Test(arguments: AppLanguage.allCases)
    func theSystemChoiceDefersToTheLocale(_ language: AppLanguage) {
        let system = time(.system, language)

        #expect(system == time(.twelveHour, language) || system == time(.twentyFourHour, language))
    }

    /// The clock choice is independent of the digits, like the language is: 24-hour form drawn in
    /// Arabic-Indic digits is a combination a single `Locale` cannot ask for.
    @Test func theClockChoiceIsIndependentOfTheDigits() {
        let formatted = service.timeString(
            from: lateAfternoon,
            language: .english,
            system: .arabicIndic,
            clock: .twentyFourHour
        )

        #expect(formatted.contains("١٧"))
    }
}
