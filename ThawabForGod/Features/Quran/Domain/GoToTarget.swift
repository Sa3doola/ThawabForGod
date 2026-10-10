//
//  GoToTarget.swift
//  ThawabForGod
//

import Foundation

/// Destination typed or picked in the Library's go-to field.
nonisolated enum GoToTarget: Hashable, Sendable {
    case page(Int)
    case ayah(VerseReference)
    case surah(Int)
    /// The ayah where the juz (1…30) or hizb (1…60) begins.
    case juz(Int)
    case hizb(Int)

    /// "50" → page 50, "2:255" → ayah 2:255, "juz 5" / "ج ٥" / "الجزء ٥", "hizb 12" / "حزب ١٢",
    /// "page 50" / "ص ٥٠", "surah 18" / "سورة ١٨". Accepts Arabic-Indic digits. Returns nil for
    /// anything outside the corpus — which, in the Tanzil fallback, is every page (Q5).
    static func parse(_ text: String, in corpus: QuranCorpus) -> GoToTarget? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let (unit, number) = unitAndNumber(trimmed) {
            switch unit {
            case .juz: return corpus.metadata.juz.contains { $0.number == number } ? .juz(number) : nil
            case .hizb: return corpus.metadata.hizb.contains { $0.number == number } ? .hizb(number) : nil
            case .page: return corpus.page(number) != nil ? .page(number) : nil
            case .surah: return corpus.surah(number) != nil ? .surah(number) : nil
            }
        }
        if let id = VerseReference(parsing: trimmed) {
            return corpus.ayah(id) == nil ? nil : .ayah(id)
        }
        if let page = Int(normalizingDigits: trimmed), corpus.page(page) != nil {
            return .page(page)
        }
        return nil
    }

    enum Unit: CaseIterable {
        case juz, hizb, page, surah

        /// Lower-cased words (English and Arabic) that name the unit before its number.
        ///
        /// Matched input rather than displayed text, which is why they are literals and not
        /// `L10nKey`s: a reader in either interface language may type either language's word.
        var words: Set<String> {
            switch self {
            case .juz: ["juz", "juz'", "juzʼ", "j", "ج", "جزء", "الجزء"]
            case .hizb: ["hizb", "h", "ح", "حزب", "الحزب"]
            case .page: ["page", "p", "ص", "صفحة", "الصفحة"]
            case .surah: ["surah", "sura", "s", "س", "سورة", "السورة"]
            }
        }
    }

    /// "juz 5", "ج٥", "Hizb. 12" → (unit, number).
    static func unitAndNumber(_ text: String) -> (Unit, Int)? {
        guard let match = text.wholeMatch(of: /([^\s\d٠-٩۰-۹.]+)\.?\s*([\d٠-٩۰-۹]+)/),
              let number = Int(normalizingDigits: String(match.output.2)) else { return nil }
        let word = String(match.output.1).lowercased()
        guard let unit = Unit.allCases.first(where: { $0.words.contains(word) }) else { return nil }
        return (unit, number)
    }
}
