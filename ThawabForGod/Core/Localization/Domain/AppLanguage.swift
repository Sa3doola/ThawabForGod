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

    /// The language the app is actually running in.
    ///
    /// Read from the bundle rather than from a stored preference, because the choice is not the
    /// app's to make. iOS gives every app shipping more than one localization a **Language** row
    /// of its own in the Settings app, and changing it there relaunches the process in the new
    /// language. That is both the platform idiom and the only switch that does not have to fight
    /// `Form` and `List` over their right-to-left mirroring — see `LocalizationManager`.
    ///
    /// `preferredLocalizations` is the intersection of what the user asked for with what this
    /// bundle actually contains, so its first entry is the localization in force. Anything that
    /// is not Arabic resolves to English, which is also the development region.
    ///
    /// - Parameter bundle: injected so a test can ask about a bundle other than whichever one
    ///   the test host happens to be running in.
    static func current(in bundle: Bundle = .main) -> AppLanguage {
        let identifier = bundle.preferredLocalizations.first ?? "en"
        return identifier.hasPrefix("ar") ? .arabic : .english
    }
}
