//
//  WidgetLocalization.swift
//  NoorWidgets
//

import Foundation

/// What `LocalizationManager` does, for a process that has no room for it.
///
/// The manager is `@Observable @MainActor`, holds preferences, and exists to be watched by
/// screens that outlive a redraw. A widget has one shot at rendering an entry it was handed, so
/// what it needs is the *formatting*, not the ownership. The rules themselves are not copied:
/// `LocaleTimeFormattingService` and `LocaleNumberFormattingService` are the same types the app
/// uses, out of `Shared/`, so digits and hour cycle cannot drift between a screen and a widget.
///
/// Strings resolve out of `Bundle.main`, which in an extension is the *extension's* bundle —
/// correct, because `Shared/Resources/Localizable.xcstrings` is compiled into both. `L10nKey`
/// still makes a missing key a compile error, which is the part of the app's rule that matters.
nonisolated struct WidgetLocalization: Sendable {

    private let style: NextPrayerSnapshot.Style
    private let times = LocaleTimeFormattingService()
    private let numbers = LocaleNumberFormattingService()

    init(_ style: NextPrayerSnapshot.Style) {
        self.style = style
    }

    /// The locale a system-rendered view should use.
    ///
    /// Carries the numbering system as a Unicode extension — `ar_SA@numbers=arab` — which is the
    /// only way to reach `Text(timerInterval:)`, whose digits the app cannot format itself.
    var locale: Locale {
        Locale(identifier: style.numberSystem.localeIdentifier)
    }

    func string(_ key: L10nKey) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .main)
    }

    func time(_ date: Date) -> String {
        times.timeString(
            from: date,
            language: style.language,
            system: style.numberSystem,
            clock: style.clockFormat
        )
    }

    /// A bare integer in the reader's digits — a Hijri day numeral, and nothing that counts.
    func number(_ value: Int) -> String {
        numbers.string(from: value, grouped: false, system: style.numberSystem)
    }

    /// A whole calendar date — `20 August 2026`.
    func date(_ date: Date) -> String {
        times.dateString(from: date, language: style.language, system: style.numberSystem)
    }

    /// The same date abbreviated and yearless — `2 Sep` — for the slots one line high.
    func shortDate(_ date: Date) -> String {
        times.shortDateString(from: date, language: style.language, system: style.numberSystem)
    }

    /// A `HijriDate` as `10 Muharram 1447`, through the same assembly the app's header uses.
    func hijri(_ date: HijriDate) -> String {
        HijriDateText.string(
            for: date,
            localized: { string($0) },
            number: { numbers.string(from: $0, grouped: $1, system: style.numberSystem) }
        )
    }

    /// A countdown as text, for the places a live timer cannot go.
    ///
    /// Comes back wrapped in Unicode directional isolates — without them the bidi algorithm
    /// reorders `6:03:49` into `6:0 3:49` on an Arabic screen, which is the app's own note about
    /// countdowns and is no less true on a Home Screen.
    func countdown(_ interval: TimeInterval) -> String {
        times.countdownString(from: interval, system: style.numberSystem)
    }
}
