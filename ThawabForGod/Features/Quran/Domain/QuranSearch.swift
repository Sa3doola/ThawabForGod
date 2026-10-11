//
//  QuranSearch.swift
//  ThawabForGod
//

import ArabicText
import Foundation

// Ported from Mushaf's `Search.swift`, with the Quran's own names: `SearchScope`, `SearchQuery`,
// `SearchHighlight` and `SearchRepository` would read as the app's search, and the hadith already
// has one of those. The Arabic is folded by `ArabicText`'s `ArabicNormalizer` — the same code that
// folded the index (T3), so a query and the text it should find cannot drift apart.

/// What the search screen looks in.
nonisolated enum QuranSearchScope: String, CaseIterable, Identifiable, Sendable {
    /// The Arabic text: FTS5 over the normalized imla'i text (`ayah_fts`).
    case quran
    /// The bundled translation packs (`pack_fts`).
    case translations

    var id: Self { self }

    var titleKey: L10nKey {
        switch self {
        case .quran: .quranTitle
        case .translations: .quranSearchScopeTranslations
        }
    }
}

/// A search query as FTS5 sees it: words folded like the index (Arabic with `ArabicNormalizer`,
/// other scripts lower-cased without diacritics, as FTS5's `unicode61 remove_diacritics 2` does),
/// split where the tokenizer splits. Every word must match; the last one also matches as a prefix,
/// so results appear while typing.
nonisolated struct QuranSearchQuery: Hashable, Sendable {
    /// Folded words, in order.
    let tokens: [String]

    /// Fewer letters than this (after folding) is too short to search.
    static let minimumLetters = 2

    /// Nil when the text has fewer than `minimumLetters` letters or digits.
    init?(_ text: String, scope: QuranSearchScope) {
        let folded = scope == .quran
            ? ArabicNormalizer.normalize(text)
            : text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).lowercased()
        let tokens = Self.words(folded)
        guard tokens.reduce(0, { $0 + $1.count }) >= Self.minimumLetters else { return nil }
        self.tokens = tokens
    }

    /// Splits where `unicode61` does: anything that is not a letter, a digit or a combining mark
    /// separates words.
    static func words(_ text: String) -> [String] {
        var words: [String] = []
        var current = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            let properties = scalar.properties
            if properties.isAlphabetic || properties.numericType != nil || properties.generalCategory == .nonspacingMark {
                current.append(scalar)
            } else if !current.isEmpty {
                words.append(String(current))
                current = String.UnicodeScalarView()
            }
        }
        if !current.isEmpty { words.append(String(current)) }
        return words
    }

    /// `"w1" "w2"*`: each word quoted (no FTS5 syntax can leak in), the last one a prefix.
    var ftsExpression: String {
        tokens.enumerated().map { index, token in
            let quoted = "\"\(token.replacingOccurrences(of: "\"", with: ""))\""
            return index == tokens.count - 1 ? quoted + "*" : quoted
        }
        .joined(separator: " ")
    }

    /// Arabic, every word in its own form: `text_norm : "w1" AND text_norm : "w2"*`.
    var exactArabicExpression: String { arabicExpression(stems: false) }

    /// Arabic, every word in its own form or as the stem of a word with attached particles
    /// (للرحمن for الرحمن). Words shorter than `ArabicPrefixStemmer.minimumStemLetters` only match
    /// their own form, so ما and لا find what they always found.
    var arabicExpression: String { arabicExpression(stems: true) }

    private func arabicExpression(stems: Bool) -> String {
        tokens.enumerated().map { index, token in
            let columns = stems && Self.usesStems(token) ? "{text_norm text_stem}" : "text_norm"
            let quoted = "\"\(token.replacingOccurrences(of: "\"", with: ""))\""
            return "\(columns) : " + (index == tokens.count - 1 ? quoted + "*" : quoted)
        }
        .joined(separator: " AND ")
    }

    /// Whether a query word also matches stems (long enough to be one).
    static func usesStems(_ token: String) -> Bool {
        token.count >= ArabicPrefixStemmer.minimumStemLetters
    }

    /// Whether a folded word of a result is one of the query's words (the last as a prefix).
    func matches(foldedWord word: String) -> Bool {
        guard !word.isEmpty else { return false }
        for (index, token) in tokens.enumerated() {
            if word == token || (index == tokens.count - 1 && word.hasPrefix(token)) { return true }
        }
        return false
    }

    /// Whether a folded Arabic word matches in its own form or through one of its stems (only the
    /// query words long enough to match stems).
    func matches(foldedArabicWord word: String) -> Bool {
        if matches(foldedWord: word) { return true }
        let stems = ArabicPrefixStemmer.stems(of: word)
        guard !stems.isEmpty else { return false }
        for (index, token) in tokens.enumerated() where Self.usesStems(token) {
            let isLast = index == tokens.count - 1
            if stems.contains(where: { $0 == token || (isLast && $0.hasPrefix(token)) }) { return true }
        }
        return false
    }

    /// Like `matches(foldedArabicWord:)` but with no prefix reading: the word, or one of its stems,
    /// must equal a query word. For highlight-only respellings, which have no index behind them to
    /// justify a prefix (إلا must not mark إِلَٰهَ just because "الاه" starts with "الا").
    func matches(exactlyFoldedArabicWord word: String) -> Bool {
        if tokens.contains(word) { return true }
        let stems = ArabicPrefixStemmer.stems(of: word)
        return tokens.contains { Self.usesStems($0) && stems.contains($0) }
    }
}

/// Arabic results: ayahs where every word matched in its own form first, then those found only
/// through a word with attached particles. Each list is in Mushaf order.
nonisolated struct QuranSearchResult: Hashable, Sendable {
    var exact: [VerseReference]
    var attached: [VerseReference]

    var count: Int { exact.count + attached.count }
    /// Exact matches first.
    var ranked: [VerseReference] { exact + attached }
}

/// Where a result's text matches the query, for highlighting (Q4: Mushaf's behaviour kept). Never
/// changes the text: it only finds ranges, and a result with no matching word is shown without a
/// highlight.
///
/// **It re-folds the displayed words**, because the index's offsets mean nothing in the displayed
/// text: the index is over the imla'i spelling, the screen shows the Uthmani. So a word whose two
/// spellings fold differently would be found but not marked — ٱلسَّمَٰوَٰتِ folds to السموت, not to
/// the السماوات a reader types — so a word with a dagger alef is also read in imla'i spelling
/// (`matchesUthmaniVariant`), by exact match only. Pinned by `QuranSearchHighlightTests`.
nonisolated enum QuranSearchHighlight {
    /// Ranges of the Hafs words whose normalized form, or one of its stems, matches (Arabic scope).
    /// Words are separated by spaces in the Hafs text.
    static func arabicRanges(in text: String, query: QuranSearchQuery) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text[start...].firstIndex(of: " ") ?? text.endIndex
            let word = text[start..<end]
            if !word.isEmpty {
                // A Hafs word folds to one search word (its marks and pause signs are dropped).
                let raw = String(word)
                let folded = QuranSearchQuery.words(ArabicNormalizer.normalize(raw)).joined()
                if query.matches(foldedArabicWord: folded) || matchesUthmaniVariant(raw, query: query) {
                    ranges.append(start..<end)
                }
            }
            start = end < text.endIndex ? text.index(after: end) : end
        }
        return ranges
    }

    /// Highlight only: the Uthmani spellings of a word with a dagger alef (U+0670) written the way
    /// imla'i writes it, so ٱلسَّمَٰوَٰتِ is marked for the السماوات a reader types. The index and
    /// `ArabicNormalizer` are untouched (T3); this adds readings, it never removes today's.
    private static func matchesUthmaniVariant(_ word: String, query: QuranSearchQuery) -> Bool {
        guard word.unicodeScalars.contains("\u{0670}") else { return false }
        return [false, true].contains { replacesWaw in
            let folded = QuranSearchQuery.words(ArabicNormalizer.normalize(uthmaniVariant(word, dagger: replacesWaw))).joined()
            return query.matches(exactlyFoldedArabicWord: folded)
        }
    }

    /// The word with each dagger alef spelled out. After ى it is dropped (موسىٰ → موسى); elsewhere
    /// it becomes ا. With `wawBecomesAlef`, a dagger after و turns that و into ا (صلوٰة → صلاة)
    /// instead of following it (سماوٰت → سماوات); both readings exist, so the caller tries both.
    private static func uthmaniVariant(_ word: String, dagger wawBecomesAlef: Bool) -> String {
        var scalars: [Unicode.Scalar] = []
        for scalar in word.unicodeScalars {
            guard scalar == "\u{0670}" else {
                scalars.append(scalar)
                continue
            }
            let baseIndex = scalars.lastIndex { $0.properties.generalCategory != .nonspacingMark }
            let base: Unicode.Scalar? = baseIndex.map { scalars[$0] }
            if base == "\u{0649}" {
                continue
            } else if base == "\u{0648}", wawBecomesAlef, let baseIndex {
                scalars[baseIndex] = "\u{0627}"
            } else {
                scalars.append("\u{0627}")
            }
        }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars)
        return String(view)
    }

    /// Ranges of the words of a translation that match (case and diacritics ignored).
    static func latinRanges(in text: String, query: QuranSearchQuery) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var wordStart: String.Index?
        var index = text.startIndex
        func close(at end: String.Index) {
            guard let start = wordStart else { return }
            let folded = String(text[start..<end]).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).lowercased()
            if query.matches(foldedWord: folded) { ranges.append(start..<end) }
            wordStart = nil
        }
        while index < text.endIndex {
            let character = text[index]
            if character.isLetter || character.isNumber {
                if wordStart == nil { wordStart = index }
            } else {
                close(at: index)
            }
            index = text.index(after: index)
        }
        close(at: text.endIndex)
        return ranges
    }
}

/// Full-text search over the bundled Quran text and translation packs.
nonisolated protocol QuranSearchRepositoring: Sendable {
    /// Ayahs whose imla'i text has every word of the query, in its own form or with attached
    /// particles; exact matches first.
    func searchQuran(_ query: QuranSearchQuery) async throws -> QuranSearchResult
    /// Ayahs whose translation has every word, per pack in the given order, in Mushaf order.
    func searchTranslations(_ query: QuranSearchQuery, packs: [ContentPackID]) async throws -> [TranslationText]
}

/// Results of one surah, for the grouped list.
nonisolated struct SurahGroup<Item: Sendable>: Identifiable, Sendable {
    let surah: Int
    let items: [Item]

    var id: Int { surah }

    /// Groups items by surah in Mushaf order, keeping each item's order inside its surah stable by
    /// ayah.
    static func groups(_ items: [Item], ayah: (Item) -> VerseReference) -> [SurahGroup<Item>] {
        let sorted = items.enumerated().sorted { lhs, rhs in
            let (a, b) = (ayah(lhs.element), ayah(rhs.element))
            return a != b ? a < b : lhs.offset < rhs.offset
        }.map(\.element)
        var groups: [SurahGroup<Item>] = []
        var current: [Item] = []
        var surah = 0
        for item in sorted {
            let next = ayah(item).surah
            if next != surah, !current.isEmpty {
                groups.append(SurahGroup(surah: surah, items: current))
                current = []
            }
            surah = next
            current.append(item)
        }
        if !current.isEmpty { groups.append(SurahGroup(surah: surah, items: current)) }
        return groups
    }
}
