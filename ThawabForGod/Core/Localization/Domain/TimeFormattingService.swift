//
//  TimeFormattingService.swift
//  ThawabForGod
//

import Foundation

/// Renders clock times and countdowns in the user's language and digits.
///
/// This is the sibling of `NumberFormattingService`, and it exists for the same reason: the
/// digit system is a separate choice from the language, so an English reader who prefers
/// Arabic-Indic digits must see `٥:٤٢ AM`. A plain `Locale(identifier: "en")` cannot express
/// that, so neither can `Text(date, style:)`.
nonisolated protocol TimeFormattingService: Sendable {
    /// A clock time — `5:42 AM`, `٥:٤٢ ص`.
    ///
    /// - Parameter clock: 12- or 24-hour form. `.system` leaves it to the locale, which is the
    ///   default; the other two cases exist because the locale's answer is a convention rather
    ///   than a preference, and a user is entitled to disagree with it.
    func timeString(
        from date: Date,
        language: AppLanguage,
        system: NumberSystem,
        clock: ClockFormat
    ) -> String

    /// A calendar date — `20 August 2026`, `٢٠ أغسطس ٢٠٢٦`.
    ///
    /// Gregorian, always. The Hijri date is a separate thing the app computes itself through
    /// `HijriDateServicing`, and letting this one follow the device's calendar would mean a user
    /// who set iOS to the Islamic calendar saw the same date twice, in two conversions that do
    /// not always agree.
    func dateString(from date: Date, language: AppLanguage, system: NumberSystem) -> String

    /// A remaining duration as `h:mm:ss`, dropping the hours component below an hour.
    /// Negative intervals clamp to zero, so a countdown that has just elapsed reads `0:00`.
    func countdownString(from interval: TimeInterval, system: NumberSystem) -> String
}
