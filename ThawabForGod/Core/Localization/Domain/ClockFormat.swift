//
//  ClockFormat.swift
//  ThawabForGod
//

import Foundation

/// Whether clock times read in 12- or 24-hour form.
///
/// The third formatting choice, and independent of the other two for the same reason they are
/// independent of each other: an English reader may want 24-hour times, an Arabic one 12-hour.
///
/// `.system` is the default and is not the same as picking whichever form the region currently
/// uses — it keeps *following* the region. Resolving it to a concrete case at first launch
/// would turn "no preference" into a choice, which is the mistake `SettingsStore`'s notes warn
/// about.
nonisolated enum ClockFormat: String, CaseIterable, Identifiable, Sendable {
    case system
    case twelveHour
    case twentyFourHour

    static let fallback: ClockFormat = .system

    var id: String { rawValue }

    /// `DateFormatter` template for this choice — a template rather than a fixed pattern, so
    /// the *order* of the parts and the position of any AM/PM marker still follow the locale.
    /// `j` is the template character that defers the hour cycle to the locale; `h` and `H`
    /// impose one.
    var dateFormatTemplate: String {
        switch self {
        case .system: "jmm"
        case .twelveHour: "hmma"
        case .twentyFourHour: "Hmm"
        }
    }

    var labelKey: L10nKey {
        switch self {
        case .system: .clockSystem
        case .twelveHour: .clockTwelveHour
        case .twentyFourHour: .clockTwentyFourHour
        }
    }
}
