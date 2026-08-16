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
    /// A clock time — `5:42 AM`, `٥:٤٢ ص` — with 12- or 24-hour form following the language.
    func timeString(from date: Date, language: AppLanguage, system: NumberSystem) -> String

    /// A remaining duration as `h:mm:ss`, dropping the hours component below an hour.
    /// Negative intervals clamp to zero, so a countdown that has just elapsed reads `0:00`.
    func countdownString(from interval: TimeInterval, system: NumberSystem) -> String
}
