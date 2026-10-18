//
//  QuranRepository.swift
//  ThawabForGod
//

import ArabicText
import Foundation
import GRDB
import SQLite3

/// Reads Quran text, layout and metadata from the bundled Quran database (`QuranDatabase`).
///
/// Ported from Mushaf's `SQLiteQuranRepository`. Every query runs on the corpus's own GRDB queue,
/// and the whole-corpus load is assembled off the main actor (`@concurrent`, T13).
///
/// **Two builds, one schema** (T4). The public build carries the text and the divisions but no
/// `word`, `mushaf_*`, `marker` or `font_ligature` rows, and says so in `meta.capabilities`. So
/// every query that needs one of those has a text-only path beside it:
///
/// - an ayah's end marker comes from its `word` row in the full build, and is written out in the
///   fallback — it is the verse number in Arabic-Indic digits in both (`InstalledCorpusTests` holds
///   the two to that);
/// - divisions and sajdahs come from the printed page's `marker` table in the full build, and from
///   the `ayah` table's own columns in the fallback, with no page;
/// - page numbers are `nil` in the fallback, and asking for a page throws
///   `QuranDataError.unsupported(.mushafPages)`.
nonisolated struct QuranRepository: QuranRepositoring {
    let database: any CorpusDatabaseProviding

    init(database: any CorpusDatabaseProviding) {
        self.database = database
    }

    // MARK: Capabilities

    @concurrent func capabilities() async throws -> QuranCapabilities {
        let value = try await database.reader().read { db in
            try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'capabilities'")
        }
        guard let value else { throw QuranDataError.invalidRow("meta has no capabilities") }
        return QuranCapabilities(meta: value)
    }

    // MARK: Whole corpus

    @concurrent func loadCorpus(style id: MushafStyleID) async throws -> QuranCorpus {
        let capabilities = try await capabilities()
        let metadata = try await metadata(style: id)
        let style = MushafStyle(id)

        guard capabilities.supportsMushafPages else {
            // The fallback: text and divisions, no pages.
            let rows = try await database.reader().read { db in
                (try Self.fetchSurahRows(db), try Self.fetchTextOnlyAyahRows(db, sql: Self.textOnlyAyahSQL + " ORDER BY a.id"))
            }
            let ayahs = rows.1.map { Ayah(id: $0.id, text: $0.text, page: nil, juz: $0.juz, marker: $0.marker) }
            return QuranCorpus(style: style, surahs: rows.0.map { $0.surah(startPage: nil) }, ayahs: ayahs, pages: [], metadata: metadata)
        }

        let styleName = id.rawValue
        let rows = try await database.reader().read { db in
            CorpusRows(
                surahs: try Self.fetchSurahRows(db),
                ayahs: try Self.fetchAyahRows(db, sql: Self.ayahSQL + " ORDER BY a.id"),
                words: try Self.fetchWords(db),
                lines: try Self.fetchLines(db, style: styleName, page: nil),
                pageJuz: try Int.fetchAll(db, sql: "SELECT juz FROM mushaf_page WHERE style = ? ORDER BY page", arguments: [styleName])
            )
        }
        var corpus = try rows.corpus(style: style, metadata: metadata)
        corpus.surahHeaderFrame = try await database.reader().read { db in
            try String.fetchOne(db, sql: "SELECT value FROM font_ligature WHERE font = 'quran-common' AND name = 'surah_header'")
        }
        return corpus
    }

    // MARK: Single queries

    @concurrent func surahs(style: MushafStyleID) async throws -> [Surah] {
        let hasPages = try await capabilities().supportsMushafPages
        let rows = try await database.reader().read { db in
            (try Self.fetchSurahRows(db), hasPages ? try Self.startPages(db, style: style.rawValue) : [:])
        }
        return rows.0.map { $0.surah(startPage: hasPages ? rows.1[$0.id] ?? 1 : nil) }
    }

    @concurrent func page(_ number: Int, style id: MushafStyleID) async throws -> MushafPage {
        guard try await capabilities().supportsMushafPages else { throw QuranDataError.unsupported(.mushafPages) }
        let style = id.rawValue
        let rows = try await database.reader().read { db -> (lines: [LineRow], words: [WordRow], juz: Int?) in
            let lines = try Self.fetchLines(db, style: style, page: number)
            let ids = lines.compactMap(\.firstWord).min().flatMap { first in lines.compactMap(\.lastWord).max().map { first...$0 } }
            let words = try ids.map { try Self.fetchWords(db, ids: $0) } ?? []
            let juz = try Int.fetchOne(db, sql: "SELECT juz FROM mushaf_page WHERE style = ? AND page = ?", arguments: [style, number])
            return (lines, words, juz)
        }
        guard let juz = rows.juz, !rows.lines.isEmpty else { throw QuranDataError.invalidRow("no page \(number)") }
        let firstID = rows.words.first?.id ?? 1
        let lines = try rows.lines.map { try $0.mushafLine(words: rows.words, firstWordID: firstID) }
        return MushafPage(number: number, juz: juz, lines: lines)
    }

    @concurrent func ayahs(surah: Int, style: MushafStyleID) async throws -> [Ayah] {
        let capabilities = try await capabilities()
        if !capabilities.contains(.words) {
            let rows = try await database.reader().read { db in
                try Self.fetchTextOnlyAyahRows(db, sql: Self.textOnlyAyahSQL + " WHERE a.surah = ? ORDER BY a.ayah", arguments: [surah])
            }
            return rows.map { Ayah(id: $0.id, text: $0.text, page: nil, juz: $0.juz, marker: $0.marker) }
        }
        let hasPages = capabilities.supportsMushafPages
        let rows = try await database.reader().read { db in
            (try Self.fetchAyahRows(db, sql: Self.ayahSQL + " WHERE a.surah = ? ORDER BY a.ayah", arguments: [surah]),
             hasPages ? try Self.ayahStartPages(db, style: style.rawValue, surah: surah) : [:])
        }
        return rows.0.map {
            Ayah(id: $0.id, text: $0.text, page: hasPages ? rows.1[$0.id.verse] ?? 1 : nil, juz: $0.juz, marker: $0.marker)
        }
    }

    @concurrent func pageNumber(for ayah: VerseReference, style: MushafStyleID) async throws -> Int {
        guard try await capabilities().supportsMushafPages else { throw QuranDataError.unsupported(.mushafPages) }
        let page = try await database.reader().read { db in
            try Int.fetchOne(db, sql: """
                SELECT min(l.page) FROM mushaf_line l, word w, ayah a
                WHERE l.style = ? AND a.surah = ? AND a.ayah = ? AND w.ayah_id = a.id AND w.position = 1
                  AND w.id BETWEEN l.first_word AND l.last_word
                """, arguments: [style.rawValue, ayah.surah, ayah.verse])
        }
        guard let page else { throw QuranDataError.invalidRow("no ayah \(ayah)") }
        return page
    }

    @concurrent func metadata(style id: MushafStyleID) async throws -> QuranMetadata {
        guard try await capabilities().supportsMushafPages else {
            return try await database.reader().read { db in try Self.textOnlyMetadata(db) }
        }
        let style = id.rawValue
        let rows = try await database.reader().read { db in
            try Row.fetchAll(db, sql: """
                SELECT m.kind, m.value, m.page, a.surah, a.ayah, a.sajdah FROM marker m JOIN ayah a ON a.id = m.ayah_id
                WHERE m.style = ? ORDER BY m.kind, m.value
                """, arguments: [style]).map { row -> (String, QuranMetadata.Start, String?) in
                (row[0], QuranMetadata.Start(number: row[1], page: row[2], ayah: VerseReference(surah: row[3], verse: row[4])), row[5])
            }
        }
        var starts: [String: [QuranMetadata.Start]] = [:]
        var sajdahs: [QuranMetadata.Sajdah] = []
        for (kind, start, type) in rows {
            if kind == "sajdah" {
                sajdahs.append(QuranMetadata.Sajdah(number: start.number, page: start.page, ayah: start.ayah, isRequired: type == "required"))
            } else {
                starts[kind, default: []].append(start)
            }
        }
        return QuranMetadata(juz: starts["juz"] ?? [], hizb: starts["hizb"] ?? [], rub: starts["rub"] ?? [], sajdahs: sajdahs)
    }

    // MARK: The fallback's metadata

    /// Divisions and sajdahs from the `ayah` table's own columns: a division starts at the first
    /// ayah carrying its number, and sajdahs are numbered in Quran order. No pages.
    private static func textOnlyMetadata(_ db: Database) throws -> QuranMetadata {
        var juz: [QuranMetadata.Start] = [], hizb: [QuranMetadata.Start] = [], rub: [QuranMetadata.Start] = []
        var sajdahs: [QuranMetadata.Sajdah] = []
        var last = (juz: 0, hizb: 0, rub: 0)
        for row in try Row.fetchAll(db, sql: "SELECT surah, ayah, juz, hizb, rub, sajdah FROM ayah ORDER BY id") {
            let ayah = VerseReference(surah: row[0], verse: row[1])
            let (j, h, r): (Int, Int, Int) = (row[2], row[3], row[4])
            if j != last.juz { juz.append(.init(number: j, page: nil, ayah: ayah)) }
            if h != last.hizb { hizb.append(.init(number: h, page: nil, ayah: ayah)) }
            if r != last.rub { rub.append(.init(number: r, page: nil, ayah: ayah)) }
            last = (j, h, r)
            if let type: String = row[5] {
                sajdahs.append(.init(number: sajdahs.count + 1, page: nil, ayah: ayah, isRequired: type == "required"))
            }
        }
        return QuranMetadata(juz: juz, hizb: hizb, rub: rub, sajdahs: sajdahs)
    }

    /// The end marker the full build stores as a `word`; the rule lives in `AyahEndMarker`, shared
    /// with the widget.
    static func markerText(verse: Int) -> String {
        AyahEndMarker.text(verse: verse)
    }

    // MARK: Rows

    private struct SurahRow: Sendable {
        let id: Int, nameAr: String, nameEn: String, ayahCount: Int, revelation: String
        let headerGlyph: String?, nameGlyph: String?

        func surah(startPage: Int?) -> Surah {
            Surah(number: id, arabicName: nameAr, englishName: nameEn, ayahCount: ayahCount,
                  revelationPlace: RevelationPlace(rawValue: revelation) ?? .makkah, startPage: startPage,
                  headerGlyph: headerGlyph, nameGlyph: nameGlyph)
        }
    }

    private struct AyahRow: Sendable {
        let id: VerseReference, juz: Int, text: String, marker: String
    }

    fileprivate struct WordRow: Sendable {
        let id: Int, surah: Int, ayah: Int, isMarker: Bool, text: String, glyph: String
    }

    fileprivate struct LineRow: Sendable {
        let page: Int, line: Int, kind: String, centered: Bool, firstWord: Int?, lastWord: Int?, surah: Int?

        /// Segments built the same way the builder's tests build them (`ArabicText`).
        func mushafLine(words: [WordRow], firstWordID: Int) throws -> MushafLine {
            let kind: MushafLine.Kind
            var segments: [Segment] = []
            switch self.kind {
            case "surah_name":
                guard let surah else { throw QuranDataError.invalidRow("header without surah, page \(page) line \(line)") }
                kind = .surahHeader(surah)
            case "basmallah":
                kind = .basmala
            case "ayah":
                guard let firstWord, let lastWord else { throw QuranDataError.invalidRow("text line without words, page \(page) line \(line)") }
                kind = .text
                let lineWords = words[(firstWord - firstWordID)...(lastWord - firstWordID)]
                // Segmentation drops the end markers; keep them (joined by ayah, not order).
                var markers: [VerseReference: WordRow] = [:]
                for word in lineWords where word.isMarker {
                    markers[VerseReference(surah: word.surah, verse: word.ayah)] = word
                }
                segments = LineSegmentation.segments(lineWords) { ($0.surah, $0.ayah, $0.isMarker) }.map {
                    let id = VerseReference(surah: $0.surah, verse: $0.ayah)
                    return Segment(
                        surah: $0.surah, verse: $0.ayah, words: $0.words.map(\.text), endsAyah: $0.endsAyah,
                        glyphs: $0.words.map(\.glyph),
                        markerGlyph: $0.endsAyah ? markers[id]?.glyph : nil,
                        markerText: $0.endsAyah ? markers[id]?.text : nil
                    )
                }
            default:
                throw QuranDataError.invalidRow("unknown line kind \(self.kind)")
            }
            return MushafLine(number: line, kind: kind, segments: segments, isCentered: centered)
        }
    }

    private struct CorpusRows: Sendable {
        let surahs: [SurahRow]
        let ayahs: [AyahRow]
        let words: [WordRow]
        let lines: [LineRow]
        let pageJuz: [Int]

        func corpus(style: MushafStyle, metadata: QuranMetadata) throws -> QuranCorpus {
            var pages: [MushafPage] = []
            var startPage: [VerseReference: Int] = [:]
            var pageLines: [MushafLine] = []
            for (index, row) in lines.enumerated() {
                let line = try row.mushafLine(words: words, firstWordID: 1)
                for segment in line.segments where startPage[segment.reference] == nil {
                    startPage[segment.reference] = row.page
                }
                pageLines.append(line)
                if index == lines.count - 1 || lines[index + 1].page != row.page {
                    guard pageJuz.indices.contains(row.page - 1) else { throw QuranDataError.invalidRow("page \(row.page) has no juz") }
                    pages.append(MushafPage(number: row.page, juz: pageJuz[row.page - 1], lines: pageLines))
                    pageLines = []
                }
            }
            let ayahs = ayahs.map { Ayah(id: $0.id, text: $0.text, page: startPage[$0.id] ?? 1, juz: $0.juz, marker: $0.marker) }
            let surahs = surahs.map { $0.surah(startPage: startPage[VerseReference(surah: $0.id, verse: 1)] ?? 1) }
            guard pages.count == style.pageCount else {
                throw QuranDataError.invalidRow("\(style.id): \(pages.count) pages, expected \(style.pageCount)")
            }
            return QuranCorpus(style: style, surahs: surahs, ayahs: ayahs, pages: pages, metadata: metadata)
        }
    }

    private static func fetchSurahRows(_ db: Database) throws -> [SurahRow] {
        // Header and name glyphs come from QUL's ligature tables (font_ligature, keyed "surah-N");
        // the fallback has none, and the joins leave them nil.
        try Row.fetchAll(db, sql: """
            SELECT s.id, s.name_ar, s.name_en, s.ayah_count, s.revelation, h.value, n.value FROM surah s
            LEFT JOIN font_ligature h ON h.font = 'surah-header' AND h.name = 'surah-' || s.id
            LEFT JOIN font_ligature n ON n.font = 'surah-name-v2' AND n.name = 'surah-' || s.id
            ORDER BY s.id
            """).map {
            SurahRow(id: $0[0], nameAr: $0[1], nameEn: $0[2], ayahCount: $0[3], revelation: $0[4], headerGlyph: $0[5], nameGlyph: $0[6])
        }
    }

    /// Ayahs with their end marker word (each ayah has exactly one; builder-tested).
    private static let ayahSQL = """
        SELECT a.id, a.surah, a.ayah, a.juz, a.text_hafs, m.text_hafs
        FROM ayah a JOIN word m ON m.ayah_id = a.id AND m.is_marker = 1
        """

    /// Ayahs alone, for a build without `word` rows: the marker is written out instead.
    private static let textOnlyAyahSQL = "SELECT a.id, a.surah, a.ayah, a.juz, a.text_hafs FROM ayah a"

    private static func fetchAyahRows(_ db: Database, sql: String, arguments: StatementArguments = []) throws -> [AyahRow] {
        try fetchRaw(db, sql: sql, arguments: arguments, capacity: 6236) {
            AyahRow(id: VerseReference(surah: $0.int(1), verse: $0.int(2)), juz: $0.int(3), text: $0.text(4), marker: $0.text(5))
        }
    }

    private static func fetchTextOnlyAyahRows(_ db: Database, sql: String, arguments: StatementArguments = []) throws -> [AyahRow] {
        try fetchRaw(db, sql: sql, arguments: arguments, capacity: 6236) {
            AyahRow(id: VerseReference(surah: $0.int(1), verse: $0.int(2)), juz: $0.int(3), text: $0.text(4),
                    marker: markerText(verse: $0.int(2)))
        }
    }

    /// The launch reads ~100k rows (words, lines, ayahs), so these skip GRDB's `Row` decoding and
    /// read columns straight from the prepared statement.
    private static func fetchRaw<T>(
        _ db: Database, sql: String, arguments: StatementArguments = [], capacity: Int = 0,
        row: (_ column: RawColumns) -> T
    ) throws -> [T] {
        let statement = try db.makeStatement(sql: sql)
        try statement.setArguments(arguments)
        let columns = RawColumns(handle: statement.sqliteStatement)
        defer { sqlite3_reset(columns.handle) }
        var result: [T] = []
        result.reserveCapacity(capacity)
        while true {
            switch sqlite3_step(columns.handle) {
            case SQLITE_ROW: result.append(row(columns))
            case SQLITE_DONE: return result
            default: throw QuranDataError.invalidRow("\(String(cString: sqlite3_errmsg(db.sqliteConnection))) in: \(sql)")
            }
        }
    }

    private struct RawColumns {
        let handle: SQLiteStatement

        func int(_ column: Int32) -> Int { Int(sqlite3_column_int64(handle, column)) }
        func optionalInt(_ column: Int32) -> Int? {
            sqlite3_column_type(handle, column) == SQLITE_NULL ? nil : int(column)
        }
        func text(_ column: Int32) -> String { String(cString: sqlite3_column_text(handle, column)) }
    }

    private static func fetchWords(_ db: Database, ids: ClosedRange<Int>? = nil) throws -> [WordRow] {
        let range = ids ?? 1...Int.max
        return try fetchRaw(db, sql: """
            SELECT w.id, a.surah, a.ayah, w.is_marker, w.text_hafs, w.glyph_v2 FROM word w JOIN ayah a ON a.id = w.ayah_id
            WHERE w.id BETWEEN ? AND ? ORDER BY w.id
            """, arguments: [range.lowerBound, range.upperBound], capacity: ids?.count ?? 84_000) {
            WordRow(id: $0.int(0), surah: $0.int(1), ayah: $0.int(2), isMarker: $0.int(3) != 0, text: $0.text(4), glyph: $0.text(5))
        }
    }

    private static func fetchLines(_ db: Database, style: String, page: Int?) throws -> [LineRow] {
        let pages = page.map { $0...$0 } ?? 1...Int.max
        return try fetchRaw(db, sql: """
            SELECT page, line, kind, centered, first_word, last_word, surah FROM mushaf_line
            WHERE style = ? AND page BETWEEN ? AND ? ORDER BY page, line
            """, arguments: [style, pages.lowerBound, pages.upperBound], capacity: page == nil ? 9100 : 16) {
            LineRow(page: $0.int(0), line: $0.int(1), kind: $0.text(2), centered: $0.int(3) != 0,
                    firstWord: $0.optionalInt(4), lastWord: $0.optionalInt(5), surah: $0.optionalInt(6))
        }
    }

    /// Page where each surah's first ayah starts.
    private static func startPages(_ db: Database, style: String) throws -> [Int: Int] {
        var pages: [Int: Int] = [:]
        for row in try Row.fetchAll(db, sql: """
            SELECT a.surah, min(l.page) FROM ayah a JOIN word w ON w.ayah_id = a.id AND w.position = 1
            JOIN mushaf_line l ON l.style = ? AND w.id BETWEEN l.first_word AND l.last_word
            WHERE a.ayah = 1 GROUP BY a.surah
            """, arguments: [style]) {
            pages[row[0]] = row[1]
        }
        return pages
    }

    /// Page where each ayah of a surah starts, by ayah number.
    private static func ayahStartPages(_ db: Database, style: String, surah: Int) throws -> [Int: Int] {
        var pages: [Int: Int] = [:]
        for row in try Row.fetchAll(db, sql: """
            SELECT a.ayah, min(l.page) FROM ayah a JOIN word w ON w.ayah_id = a.id AND w.position = 1
            JOIN mushaf_line l ON l.style = ? AND w.id BETWEEN l.first_word AND l.last_word
            WHERE a.surah = ? GROUP BY a.ayah
            """, arguments: [style, surah]) {
            pages[row[0]] = row[1]
        }
        return pages
    }
}
