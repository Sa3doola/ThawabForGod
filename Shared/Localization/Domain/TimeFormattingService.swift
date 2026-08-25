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

    /// The shortest form of a weekday name — `S`, `M`, `ح`, `ن` — for the week strip, where
    /// seven of them share a phone's width and there is room for a letter and nothing more.
    ///
    /// No `NumberSystem`: a weekday name has no digits in it. Gregorian for the reason
    /// `dateString(from:language:system:)` is.
    func weekdayString(from date: Date, language: AppLanguage) -> String

    /// A remaining duration as `h:mm:ss`, dropping the hours component below an hour.
    /// Negative intervals clamp to zero, so a countdown that has just elapsed reads `0:00`.
    func countdownString(from interval: TimeInterval, system: NumberSystem) -> String

    /// The same duration in the form a *label that cannot be allowed to move* wants: `h:mm`
    /// above the hour, `mm:ss` inside it. Always four or five characters, in either digit system.
    ///
    /// **Not a shorter `countdownString(_:)` — a different rule, for a different reader.** On a
    /// screen the seconds are worth showing because the reader is looking at the screen. In the
    /// macOS menu bar they are worth less than the cost of them: a label that rewrites itself
    /// once a second all day is a label that keeps catching the eye of somebody trying to work,
    /// and — since the item only redraws every half minute outside the final hour — a seconds
    /// figure up there would be *stale* between beats, jumping by thirty rather than counting.
    ///
    /// So the seconds arrive exactly when they start to matter, at the hour boundary, which is
    /// also the one moment the slot is allowed to change shape. See `MenuBarStatusSlot`.
    func briefCountdownString(from interval: TimeInterval, system: NumberSystem) -> String
}
