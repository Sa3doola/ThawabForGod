//
//  HijriDateText.swift
//  ThawabForGod
//

import Foundation

/// A `HijriDate` as a line of text, assembled once for every process that draws one.
///
/// **A composition rather than a `DateFormatter`.** A formatter could produce this in one call,
/// but only by following the locale for both the month name *and* the digits — and this app
/// treats those as separate choices, so an Arabic reader who prefers Latin digits would get
/// Arabic-Indic ones anyway. Assembling the three pieces keeps each on the setting that governs
/// it.
///
/// It takes its two lookups as parameters rather than a `LocalizationManager`, because the manager
/// is `@MainActor` and a widget process has no room for one — it has `WidgetLocalization` instead.
/// Both call this, so the app's header and a Lock Screen line cannot come out differently spelled.
nonisolated enum HijriDateText {

    /// `10 Muharram 1447`, `١٠ محرم ١٤٤٧`.
    ///
    /// - Parameters:
    ///   - localized: resolves a month's `L10nKey`. The caller's bundle, whichever process it is.
    ///   - number: renders an integer in the reader's digits. `grouped` is passed as `false` for
    ///     the year — it names a year, it does not count 1,448 of anything.
    static func string(
        for date: HijriDate,
        localized: (L10nKey) -> String,
        number: (Int, Bool) -> String
    ) -> String {
        // One interpolated run rather than three pieces a view stacks: a stack would fix the
        // visual order of day, month and year, whereas a single run lets the bidi algorithm lay
        // them out the way the reading direction requires.
        "\(number(date.day, true)) \(localized(date.month.labelKey)) \(number(date.year, false))"
    }

    /// Both calendars on one line — `10 Muharram 1447 · 2 Sep`.
    ///
    /// The separator is a middle dot with spaces around it, which is what the app's own header
    /// uses. It is direction-neutral, so the same string reads correctly mirrored.
    static func combined(hijri: String, gregorian: String) -> String {
        "\(hijri) · \(gregorian)"
    }
}
