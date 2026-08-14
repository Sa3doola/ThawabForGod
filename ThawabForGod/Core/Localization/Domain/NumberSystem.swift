//
//  NumberSystem.swift
//  ThawabForGod
//

import Foundation

/// Which digits numbers are drawn with. Independent of language: an Arabic reader may
/// prefer Latin digits, and vice versa.
nonisolated enum NumberSystem: String, CaseIterable, Identifiable, Sendable {
    case arabicIndic
    case latin

    var id: String { rawValue }

    /// Locale identifier carrying the numbering-system extension the formatter needs.
    var localeIdentifier: String {
        switch self {
        case .arabicIndic: "ar_SA@numbers=arab"
        // `en_US`, not `en_US_POSIX`: POSIX drops grouping separators, and a four-digit
        // count should read the same way in both systems.
        case .latin: "en_US@numbers=latn"
        }
    }

    var labelKey: L10nKey {
        switch self {
        case .arabicIndic: .numbersArabicIndic
        case .latin: .numbersLatin
        }
    }

    /// The digits to start with for a given language.
    static func preferred(for language: AppLanguage) -> NumberSystem {
        language == .arabic ? .arabicIndic : .latin
    }
}
