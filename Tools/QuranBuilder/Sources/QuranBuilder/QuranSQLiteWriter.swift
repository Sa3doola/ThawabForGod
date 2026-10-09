import ArabicText
import Foundation
import QuranDataModel

/// Schema of the Quran database, the same for both profiles. Bump `schemaVersion` on any change.
///
/// Mushaf's schema 3, unchanged: the app's screens are ported from Mushaf and read these tables.
/// A profile that has no page layout leaves the layout tables empty rather than omitting them,
/// and says what it filled in `meta.capabilities` — so the app asks one question of `meta` instead
/// of probing for tables.
enum QuranSchema {
    static let schemaVersion = 3

    static let statements = [
        """
        CREATE TABLE surah (id INTEGER PRIMARY KEY, name_ar TEXT, name_en TEXT, name_translit TEXT,
          ayah_count INT, revelation TEXT, revelation_order INT, bismillah_pre INT)
        """,
        """
        CREATE TABLE ayah (id INTEGER PRIMARY KEY, surah INT, ayah INT, juz INT, hizb INT, rub INT,
          manzil INT, ruku INT, sajdah TEXT NULL, text_hafs TEXT, text_imlaei TEXT, UNIQUE(surah, ayah))
        """,
        """
        CREATE TABLE word (id INTEGER PRIMARY KEY, ayah_id INT REFERENCES ayah(id), position INT,
          is_marker INT, text_hafs TEXT, glyph_v2 TEXT, glyph_v1 TEXT NULL)
        """,
        "CREATE INDEX word_ayah ON word(ayah_id)",
        """
        CREATE TABLE mushaf_line (style TEXT, page INT, line INT, kind TEXT, centered INT,
          first_word INT NULL, last_word INT NULL, surah INT NULL, PRIMARY KEY(style, page, line))
        """,
        """
        CREATE TABLE mushaf_page (style TEXT, page INT, first_ayah INT, last_ayah INT, juz INT,
          hizb INT, rub INT, PRIMARY KEY(style, page))
        """,
        "CREATE TABLE marker (style TEXT, page INT, kind TEXT, value INT, ayah_id INT)",
        // text_norm: the folded search text (ArabicNormalizer). text_stem: the stems of the words
        // that carry attached particles (ArabicPrefixStemmer), so للرحمن is also found as الرحمن.
        "CREATE VIRTUAL TABLE ayah_fts USING fts5(text_norm, text_stem, content='', tokenize='unicode61 remove_diacritics 2')",
        "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)",
        // QUL ligature tables, values trimmed: font id ('surah-header', 'surah-name-v2',
        // 'quran-common') + name ('surah-2', 'juz-3-name') → the string that draws it.
        "CREATE TABLE font_ligature (font TEXT, name TEXT, value TEXT, PRIMARY KEY(font, name))",
    ]
}

/// What a profile can fill, written to `meta.capabilities` as a comma-separated list.
enum Capability: String, CaseIterable {
    /// `surah`, `ayah` and `ayah_fts`: every profile.
    case text
    /// `word`: the word-by-word Hafs text and its end markers.
    case words
    /// `mushaf_line`, `mushaf_page` and `marker`: the printed page layout. Without it the app
    /// hides Mushaf mode and the Library's Page tab.
    case mushafPages
    /// `word.glyph_v2`: the V2 glyph codes drawn with the per-page fonts.
    case glyphV2
    /// `font_ligature`: the QUL header, surah-name and juz-name fonts.
    case fontLigatures
}

// MARK: Rows

struct SurahRow {
    let id: Int
    let nameAr: String
    let nameEn: String
    let nameTranslit: String
    let ayahCount: Int
    /// "makkah" or "madinah".
    let revelation: String
    let revelationOrder: Int
    let bismillahPre: Bool
}

struct AyahRow {
    /// Global index 1…6236 in canonical order.
    let id: Int
    let surah: Int
    let ayah: Int
    let juz: Int
    let hizb: Int
    let rub: Int
    let manzil: Int
    let ruku: Int
    /// "required" or "optional"; `nil` for all but fifteen ayahs.
    let sajdah: String?
    /// What is displayed, stored verbatim (the basmala that opens a surah is not part of verse 1).
    let textHafs: String
    /// What is searched: the same ayah in imla'i spelling, folded into `ayah_fts`.
    let textImlaei: String
}

struct WordRow {
    let id: Int
    let ayahID: Int
    let position: Int
    let isMarker: Bool
    let textHafs: String
    let glyphV2: String
}

struct LineRow {
    let style: String
    let page: Int
    let line: Int
    let kind: String
    let isCentered: Bool
    let firstWord: Int?
    let lastWord: Int?
    let surah: Int?
}

struct PageRow {
    let style: String
    let page: Int
    let firstAyah: Int
    let lastAyah: Int
    let juz: Int
    let hizb: Int
    let rub: Int
}

struct MarkerRow {
    let style: String
    let page: Int
    let kind: String
    let value: Int
    let ayahID: Int
}

/// Everything a profile hands the writer. Tables a profile has nothing for stay empty.
struct QuranCorpusRows {
    var surahs: [SurahRow]
    var ayahs: [AyahRow]
    var words: [WordRow] = []
    var lines: [LineRow] = []
    var pages: [PageRow] = []
    var markers: [MarkerRow] = []
    var ligatures: [LigatureTable] = []
    var capabilities: [Capability]
    /// Provenance: generator, profile, input hashes, source notices.
    var meta: [(String, String)]

    /// "s:a" → ayah id, for the packs and the curated lists.
    var ayahIDs: [String: Int] {
        Dictionary(uniqueKeysWithValues: ayahs.map { ("\($0.surah):\($0.ayah)", $0.id) })
    }

    /// The highest ayah number of each surah (index 0 = surah 1).
    var ayahCounts: [Int] { surahs.map(\.ayahCount) }
}

// MARK: Writing

struct QuranSQLiteWriter {
    struct Summary {
        let ayahs: Int
        let words: Int
        let markers: Int
        let pagesByStyle: [String: Int]
        let bytes: Int
    }

    let profile: Profile

    func write(_ rows: QuranCorpusRows, to url: URL) throws -> Summary {
        try check(rows)

        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let db = try SQLiteDatabase(path: url.path, readOnly: false)
        try db.execute("PRAGMA journal_mode = DELETE")
        for statement in QuranSchema.statements { try db.execute(statement) }

        try db.transaction {
            let insertSurah = try db.prepare("INSERT INTO surah VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
            for surah in rows.surahs {
                try insertSurah.run([
                    .int(surah.id), .text(surah.nameAr), .text(surah.nameEn), .text(surah.nameTranslit),
                    .int(surah.ayahCount), .text(surah.revelation), .int(surah.revelationOrder),
                    .int(surah.bismillahPre ? 1 : 0),
                ])
            }

            let insertAyah = try db.prepare("INSERT INTO ayah VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
            let insertSearch = try db.prepare("INSERT INTO ayah_fts (rowid, text_norm, text_stem) VALUES (?, ?, ?)")
            for ayah in rows.ayahs {
                try insertAyah.run([
                    .int(ayah.id), .int(ayah.surah), .int(ayah.ayah),
                    .int(ayah.juz), .int(ayah.hizb), .int(ayah.rub), .int(ayah.manzil), .int(ayah.ruku),
                    SQLiteValue(ayah.sajdah), .text(ayah.textHafs), .text(ayah.textImlaei),
                ])
                // Search indexes the imla'i text, folded exactly as the app folds queries, and the
                // stems of its words with attached particles. The stored text is never changed.
                let normalized = ArabicNormalizer.normalize(ayah.textImlaei)
                try insertSearch.run([.int(ayah.id), .text(normalized), .text(ArabicPrefixStemmer.stemText(normalized))])
            }

            let insertWord = try db.prepare("INSERT INTO word VALUES (?, ?, ?, ?, ?, ?, NULL)")
            for word in rows.words {
                try insertWord.run([
                    .int(word.id), .int(word.ayahID), .int(word.position),
                    .int(word.isMarker ? 1 : 0), .text(word.textHafs), .text(word.glyphV2),
                ])
            }

            let insertLine = try db.prepare("INSERT INTO mushaf_line VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
            for row in rows.lines {
                try insertLine.run([
                    .text(row.style), .int(row.page), .int(row.line), .text(row.kind),
                    .int(row.isCentered ? 1 : 0), SQLiteValue(row.firstWord), SQLiteValue(row.lastWord),
                    SQLiteValue(row.surah),
                ])
            }

            let insertPage = try db.prepare("INSERT INTO mushaf_page VALUES (?, ?, ?, ?, ?, ?, ?)")
            for page in rows.pages {
                try insertPage.run([
                    .text(page.style), .int(page.page), .int(page.firstAyah), .int(page.lastAyah),
                    .int(page.juz), .int(page.hizb), .int(page.rub),
                ])
            }

            let insertMarker = try db.prepare("INSERT INTO marker VALUES (?, ?, ?, ?, ?)")
            for marker in rows.markers {
                try insertMarker.run([
                    .text(marker.style), .int(marker.page), .text(marker.kind), .int(marker.value), .int(marker.ayahID),
                ])
            }

            let insertLigature = try db.prepare("INSERT INTO font_ligature VALUES (?, ?, ?)")
            for table in rows.ligatures {
                for name in table.entries.keys.sorted() {
                    try insertLigature.run([.text(table.font), .text(name), .text(table.entries[name]!)])
                }
            }

            let insertMeta = try db.prepare("INSERT INTO meta VALUES (?, ?)")
            let meta: [(String, String)] = [
                ("schema_version", String(QuranSchema.schemaVersion)),
                ("generator", "Tools/QuranBuilder"),
                ("profile", profile.rawValue),
                ("capabilities", rows.capabilities.map(\.rawValue).joined(separator: ",")),
                ("built_at", ISO8601DateFormatter().string(from: Date())),
            ] + rows.meta
            for (key, value) in meta { try insertMeta.run([.text(key), .text(value)]) }
        }
        try db.execute("INSERT INTO ayah_fts (ayah_fts) VALUES ('optimize')")
        try db.execute("VACUUM")

        let bytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return Summary(
            ayahs: rows.ayahs.count,
            words: rows.words.filter { !$0.isMarker }.count,
            markers: rows.words.filter(\.isMarker).count,
            pagesByStyle: Dictionary(grouping: rows.pages, by: \.style).mapValues(\.count),
            bytes: bytes
        )
    }

    /// What every profile must hand over, whatever its source: the whole Quran, in order, with
    /// every capability it claims actually filled.
    private func check(_ rows: QuranCorpusRows) throws {
        try require(rows.surahs.map(\.id) == Array(1...114), "surahs are not 1…114")
        try require(rows.ayahs.count == 6236, "\(rows.ayahs.count) ayahs, expected 6,236")
        try require(rows.ayahs.map(\.id) == Array(1...rows.ayahs.count), "ayah ids are not 1…\(rows.ayahs.count)")
        try require(
            rows.ayahs.map { "\($0.surah):\($0.ayah)" } == rows.surahs.flatMap { s in (1...s.ayahCount).map { "\(s.id):\($0)" } },
            "ayahs are not in canonical order"
        )
        try require(rows.ayahs.allSatisfy { !$0.textHafs.isEmpty && !$0.textImlaei.isEmpty }, "an ayah has no text")
        try require(Set(rows.surahs.map(\.revelation)).isSubset(of: ["makkah", "madinah"]), "unknown revelation place")
        try require(Set(rows.ayahs.compactMap(\.sajdah)).isSubset(of: ["required", "optional"]), "unknown sajdah type")
        try require(rows.ayahs.compactMap(\.sajdah).count == 15, "expected 15 sajdahs")

        let claimed = Set(rows.capabilities)
        try require(claimed.contains(.text), "every profile writes the text")
        try require(claimed.contains(.words) == !rows.words.isEmpty, "words claimed and filled must agree")
        try require(claimed.contains(.mushafPages) == !(rows.lines.isEmpty || rows.pages.isEmpty), "pages claimed and filled must agree")
        try require(claimed.contains(.fontLigatures) == !rows.ligatures.isEmpty, "ligatures claimed and filled must agree")
        try require(!claimed.contains(.glyphV2) || rows.words.allSatisfy { !$0.glyphV2.isEmpty }, "glyphs claimed but missing")
    }
}
