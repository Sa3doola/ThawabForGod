//
//  LocalizationManager.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// Resolves strings and numbers for the language the app is running in, and owns the two
/// formatting choices that are the app's own.
///
/// **The language is not one of them.** It belongs to the system: iOS lists this app in the
/// Settings app with a Language row of its own, because the bundle ships both `ar.lproj` and
/// `en.lproj`, and picking there relaunches the process. That is deliberate rather than a
/// limitation — an in-app switcher used to live here, and it could not be made to work.
/// `Form` and `List` are UIKit-backed, and they decide their right-to-left mirroring once, when
/// the backing view is created; flipping `\.layoutDirection` under a live one leaves the
/// transform in place and renders every glyph backwards. Rebuilding the hierarchy with an `.id`
/// did not reliably clear it either. Letting the system relaunch the app sidesteps the whole
/// class of problem, and is what a reader of either language already expects.
///
/// What stays here is what the system cannot express: `NumberSystem` and `ClockFormat`. An
/// Arabic reader may want Latin digits, and a reader of either language may want a 24-hour
/// clock; a single `Locale` has no way to say that, which is why these two are still the app's.
///
/// Strings still resolve through `string(_:)` rather than `Text("key")` — not to switch at
/// runtime any more, but because `L10nKey` makes a missing key a compile error and gives the
/// catalog a single door.
@Observable
@MainActor
final class LocalizationManager {

    /// The language in force, fixed for the lifetime of the process.
    ///
    /// A `let`, and that is the point: nothing in the app may change it, so no screen has to
    /// cope with it changing underneath. A new value arrives the only way it can — a relaunch.
    let language: AppLanguage

    private(set) var numberSystem: NumberSystem
    private(set) var clockFormat: ClockFormat

    @ObservationIgnored private let settingsStore: any SettingsStore
    @ObservationIgnored private let numberFormatting: any NumberFormattingService
    @ObservationIgnored private let timeFormatting: any TimeFormattingService

    init(
        settingsStore: any SettingsStore,
        numberFormatting: any NumberFormattingService,
        timeFormatting: any TimeFormattingService,
        language: AppLanguage = .current()
    ) {
        self.settingsStore = settingsStore
        self.numberFormatting = numberFormatting
        self.timeFormatting = timeFormatting

        self.language = language
        self.numberSystem = settingsStore.string(for: .numberSystem)
            .flatMap(NumberSystem.init(rawValue:)) ?? .preferred(for: language)
        // No `preferred(for:)` equivalent: the fallback keeps deferring to the locale rather
        // than resolving to a case, so a device that changes region is still followed.
        self.clockFormat = settingsStore.string(for: .clockFormat)
            .flatMap(ClockFormat.init(rawValue:)) ?? .fallback
    }

    // MARK: Choices

    func select(numberSystem: NumberSystem) {
        self.numberSystem = numberSystem
        settingsStore.set(numberSystem.rawValue, for: .numberSystem)
    }

    func select(clockFormat: ClockFormat) {
        self.clockFormat = clockFormat
        settingsStore.set(clockFormat.rawValue, for: .clockFormat)
    }

    // MARK: Resolved values

    /// `autoupdatingCurrent` rather than one built from `language`, now that the process is
    /// already running in the right language: the system's locale carries the user's *region*
    /// too, and `Locale(identifier: "ar")` would throw that away.
    var locale: Locale { .autoupdatingCurrent }

    /// The main bundle, because the process launched in the language the user picked and its
    /// `.lproj` is the one `String(localized:)` will reach for.
    ///
    /// This used to hunt for a specific `.lproj` so a runtime switch could read the other
    /// language's strings. Nothing switches at runtime any more, so the lookup went with it.
    private var bundle: Bundle { .main }

    func string(_ key: L10nKey) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: bundle, locale: locale)
    }

    /// A string with values substituted into it — `%1$@`, `%2$@` — resolved in the app's
    /// language.
    ///
    /// Positional placeholders rather than bare `%@` in the catalog, because Arabic and English
    /// do not always want the parts in the same order, and a positional form lets the
    /// translation move them without the call site changing.
    ///
    /// Arguments arrive already formatted. Anything numeric must have been through `string(_:)`
    /// or `timeString(_:)` first — passing an `Int` here would print it in whatever digits
    /// `String(format:)` felt like, which is the one thing this app does not leave to chance.
    func string(_ key: L10nKey, _ arguments: any CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    /// - Parameter grouped: pass `false` for a number that names rather than counts — a year,
    ///   a page, an ayah — where a thousands separator would be wrong in every locale.
    func string(_ value: Int, grouped: Bool = true) -> String {
        numberFormatting.string(from: value, grouped: grouped, system: numberSystem)
    }

    func string(_ value: Double, fractionDigits: Int = 1) -> String {
        numberFormatting.string(from: value, fractionDigits: fractionDigits, system: numberSystem)
    }

    /// A clock time in the user's language and digits. Prefer this over `Text(date, style:)`,
    /// which can only follow the locale and so cannot honour a digit choice made separately
    /// from the language.
    func timeString(_ date: Date) -> String {
        timeFormatting.timeString(
            from: date,
            language: language,
            system: numberSystem,
            clock: clockFormat
        )
    }

    /// A Gregorian calendar date in the user's language and digits.
    func dateString(_ date: Date) -> String {
        timeFormatting.dateString(from: date, language: language, system: numberSystem)
    }

    /// The same date abbreviated and without the year — `2 Sep`.
    func shortDateString(_ date: Date) -> String {
        timeFormatting.shortDateString(from: date, language: language, system: numberSystem)
    }

    /// A remaining duration as `h:mm:ss`.
    /// One letter for a weekday — the week strip's column heading.
    func weekdayString(_ date: Date) -> String {
        timeFormatting.weekdayString(from: date, language: language)
    }

    func countdownString(_ interval: TimeInterval) -> String {
        timeFormatting.countdownString(from: interval, system: numberSystem)
    }

    /// `h:mm` above the hour, `mm:ss` inside it — the form a label that must not move wants.
    /// See `TimeFormattingService.briefCountdownString(from:system:)`.
    func briefCountdownString(_ interval: TimeInterval) -> String {
        timeFormatting.briefCountdownString(from: interval, system: numberSystem)
    }
}
