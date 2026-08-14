//
//  AppLanguage.swift
//  ThawabForGod
//

import Foundation

/// The languages the app ships. Both are first-class: Arabic is not a translation of English.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case arabic = "ar"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    var isRightToLeft: Bool { self == .arabic }

    var labelKey: L10nKey {
        switch self {
        case .arabic: .languageArabic
        case .english: .languageEnglish
        }
    }

    /// The language to start in when the user has never chosen one.
    static var preferred: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ar") ? .arabic : .english
    }
}
