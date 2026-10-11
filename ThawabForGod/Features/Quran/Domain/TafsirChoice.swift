//
//  TafsirChoice.swift
//  ThawabForGod
//

import Foundation

/// Which tafsirs the panel offers and which one it shows. Pure, so the rules are tested without
/// views. M5.6 will feed it the Settings keys; until then `enabled` and `defaultTafsir` are nil.
nonisolated enum TafsirChoice {
    /// Enabled tafsirs in the user's order; nil `enabled` means every installed tafsir. Packs of
    /// other kinds and ids that are not installed are skipped.
    static func enabled(installed: [ContentPack], enabled: [ContentPackID]?) -> [ContentPack] {
        let tafsirs = installed.filter { $0.kind == .tafsir }
        guard let enabled else { return tafsirs }
        return enabled.compactMap { id in tafsirs.first { $0.id == id } }
    }

    /// The tafsir to show: the one picked in the panel if still enabled, else the default from
    /// Settings if enabled, else the first enabled one in the app's language, else the first
    /// enabled one.
    static func current(
        enabled: [ContentPack],
        picked: ContentPackID?,
        defaultTafsir: ContentPackID?,
        appLanguage: String?
    ) -> ContentPack? {
        for id in [picked, defaultTafsir].compactMap({ $0 }) {
            if let pack = enabled.first(where: { $0.id == id }) { return pack }
        }
        return enabled.first { $0.language == appLanguage } ?? enabled.first
    }
}
