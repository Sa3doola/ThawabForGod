//
//  ContentPack.swift
//  ThawabForGod
//

import Foundation

/// Identifies a bundled translation or tafsir pack, e.g. "en-sahih-international".
nonisolated struct ContentPackID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String { rawValue }

    init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// What a pack holds. The raw value is the pack's own `pack.kind` and the prefix of its file name,
/// which is how the app finds packs without a manifest (T15).
nonisolated enum ContentPackKind: String, Codable, CaseIterable, Sendable {
    case translation, tafsir
    /// Surah introductions: one text per surah.
    case surahInfo = "surah-info"

    /// `translation-`, `tafsir-`, `surah-info-`.
    var filePrefix: String { rawValue + "-" }
}

/// One surah's introduction from a surah-info pack: a short summary and the full text in the tafsir
/// HTML subset.
nonisolated struct SurahInfo: Hashable, Sendable {
    let pack: ContentPackID
    let surah: Int
    let summary: String
    let html: String
}

/// Direction of a pack's text; the reader itself is forced right-to-left, so every pack view sets
/// its own direction.
nonisolated enum TextDirection: String, Codable, Sendable {
    case ltr, rtl

    var isRightToLeft: Bool { self == .rtl }
}

/// A pack's name or author in the app's two languages (`pack.name` / `pack.name_ar`, …).
nonisolated struct LocalizedPackText: Hashable, Codable, Sendable {
    let en: String
    let ar: String

    init(en: String, ar: String) {
        self.en = en
        self.ar = ar
    }

    /// The same text in both languages (tests, previews).
    init(_ text: String) {
        self.init(en: text, ar: text)
    }

    /// The Arabic text for an Arabic interface, the English text for anything else.
    func value(in language: AppLanguage) -> String {
        language == .arabic ? ar : en
    }

    /// The same, from a language code ("ar", "en", or `nil`).
    func value(for language: String?) -> String {
        language == "ar" ? ar : en
    }
}

/// One bundled pack, as it describes itself in its own `pack` table.
nonisolated struct ContentPack: Identifiable, Hashable, Sendable {
    let id: ContentPackID
    let kind: ContentPackKind
    /// BCP 47 language code ("en", "ar"): the language of the pack's text.
    let language: String
    let names: LocalizedPackText
    let authors: LocalizedPackText
    let direction: TextDirection
    let version: Int
    /// File name in the bundle, with its extension — `tafsir-ar-jalalayn.sqlite`.
    let file: String
    let license: String

    init(
        id: ContentPackID, kind: ContentPackKind, language: String, names: LocalizedPackText, authors: LocalizedPackText,
        direction: TextDirection, version: Int, file: String, license: String
    ) {
        self.id = id
        self.kind = kind
        self.language = language
        self.names = names
        self.authors = authors
        self.direction = direction
        self.version = version
        self.file = file
        self.license = license
    }

    /// The name in the interface's language (not the pack's own language).
    func name(in language: AppLanguage) -> String { names.value(in: language) }
    func author(in language: AppLanguage) -> String { authors.value(in: language) }
}

/// One ayah of one translation: plain text with `[[fn:ID]]` footnote tokens and `*italics*`, and
/// the notes by ID. The translation markup turns it into styled text (M5).
nonisolated struct TranslationText: Hashable, Sendable {
    let pack: ContentPackID
    let ayah: VerseReference
    let text: String
    let footnotes: [String: String]
}

/// One ayah's entry in one tafsir. Tafsirs often explain several ayahs together; every ayah of such
/// a group gets the same text and the whole range.
///
/// An ayah a commentary passes over has **no** entry: the repository answers `nil`, never a
/// neighbour's note (T16). Tafsir al-Jalalayn is silent on 226 ayahs.
nonisolated struct TafsirEntry: Hashable, Sendable {
    let pack: ContentPackID
    /// The ayah that was asked for.
    let ayah: VerseReference
    /// The ayahs this text covers, in one surah (the builder checks that groups are contiguous and
    /// stay in one surah). A single ayah for most entries.
    let range: ClosedRange<VerseReference>
    /// The builder's HTML subset: the tafsir markup parses it (M5).
    let html: String

    /// The text covers more than the one ayah: show "Tafsir of ayahs 2:3–5".
    var isGroup: Bool { range.lowerBound != range.upperBound }
}

extension TafsirEntry {
    /// "2:3–5" (one surah) or "2:286–3:1"; "2:255" for one ayah. Each number goes through
    /// `format`, which is `LocalizationManager`'s number formatting at the call site — the digits
    /// are the reader's choice, not this type's.
    ///
    /// Arabic-Indic digits are Arabic numbers to the bidi algorithm, so a dash between two of them
    /// resolves right-to-left and "٢:٣–٤" would show as "٤–٢:٣" in left-to-right text. In
    /// left-to-right text the dash gets left-to-right marks on both sides; right-to-left text keeps
    /// the natural order, which reads correctly there.
    nonisolated func rangeText(format: (Int) -> String, isRightToLeft: Bool = false) -> String {
        let first = range.lowerBound, last = range.upperBound
        let start = "\(format(first.surah)):\(format(first.verse))"
        if first == last { return start }
        let dash = isRightToLeft ? "–" : "\u{200E}–\u{200E}"
        if first.surah == last.surah { return "\(start)\(dash)\(format(last.verse))" }
        return "\(start)\(dash)\(format(last.surah)):\(format(last.verse))"
    }
}
