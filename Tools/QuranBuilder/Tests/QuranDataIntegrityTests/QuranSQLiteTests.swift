// Validates the built Quran database (the qul profile's quran-mushaf.sqlite) and the verified facts
// about the raw QUL inputs when QuranData/raw is present.

import ArabicText
import CoreGraphics
import CoreText
import Foundation
import QuranDataModel
import Testing

/// quran.sqlite loaded once into plain values.
struct QuranSQLite: Sendable {
    struct Word: Sendable { let id: Int, ayahID: Int, surah: Int, ayah: Int, position: Int, isMarker: Bool, hafs: String, glyphV2: String }
    struct Ayah: Sendable {
        let id: Int, surah: Int, ayah: Int, juz: Int, hizb: Int, rub: Int, manzil: Int, ruku: Int
        let sajdah: String?, textHafs: String, textImlaei: String
    }
    struct Line: Sendable { let page: Int, line: Int, kind: String, centered: Bool, firstWord: Int?, lastWord: Int?, surah: Int? }
    struct Page: Sendable { let page: Int, firstAyah: Int, lastAyah: Int, juz: Int, hizb: Int, rub: Int }
    struct Marker: Sendable { let page: Int, kind: String, value: Int, ayahID: Int }

    let surahs: [(id: Int, nameAr: String, nameEn: String, ayahCount: Int, revelation: String)]
    let ayahs: [Ayah]
    let words: [Word]
    let lines: [Line]
    let pages: [Page]
    let markers: [Marker]
    let meta: [String: String]
    let nullableTypes: [String: Set<String>]

    static let style = "madaniV2"

    static let shared: QuranSQLite = {
        do { return try load() } catch { fatalError("Cannot read \(Paths.quranSQLite.path): \(error). Run `swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile qul` first.") }
    }()

    private static func load() throws -> QuranSQLite {
        let db = try SQLiteDatabase(path: Paths.quranSQLite.path, readOnly: true)
        var surahs: [(Int, String, String, Int, String)] = []
        try db.query("SELECT id, name_ar, name_en, ayah_count, revelation FROM surah ORDER BY id") {
            surahs.append(($0.int(0)!, $0.text(1)!, $0.text(2)!, $0.int(3)!, $0.text(4)!))
        }
        var ayahs: [Ayah] = []
        try db.query("SELECT id, surah, ayah, juz, hizb, rub, manzil, ruku, sajdah, text_hafs, text_imlaei FROM ayah ORDER BY id") {
            ayahs.append(Ayah(id: $0.int(0)!, surah: $0.int(1)!, ayah: $0.int(2)!, juz: $0.int(3)!, hizb: $0.int(4)!, rub: $0.int(5)!,
                              manzil: $0.int(6)!, ruku: $0.int(7)!, sajdah: $0.text(8), textHafs: $0.text(9)!, textImlaei: $0.text(10)!))
        }
        var words: [Word] = []
        try db.query("""
            SELECT w.id, w.ayah_id, a.surah, a.ayah, w.position, w.is_marker, w.text_hafs, w.glyph_v2
            FROM word w JOIN ayah a ON a.id = w.ayah_id ORDER BY w.id
            """) {
            words.append(Word(id: $0.int(0)!, ayahID: $0.int(1)!, surah: $0.int(2)!, ayah: $0.int(3)!, position: $0.int(4)!,
                              isMarker: $0.int(5) == 1, hafs: $0.text(6)!, glyphV2: $0.text(7)!))
        }
        var lines: [Line] = []
        try db.query("SELECT page, line, kind, centered, first_word, last_word, surah FROM mushaf_line WHERE style = ? ORDER BY page, line", [.text(style)]) {
            lines.append(Line(page: $0.int(0)!, line: $0.int(1)!, kind: $0.text(2)!, centered: $0.int(3) == 1,
                              firstWord: $0.int(4), lastWord: $0.int(5), surah: $0.int(6)))
        }
        var pages: [Page] = []
        try db.query("SELECT page, first_ayah, last_ayah, juz, hizb, rub FROM mushaf_page WHERE style = ? ORDER BY page", [.text(style)]) {
            pages.append(Page(page: $0.int(0)!, firstAyah: $0.int(1)!, lastAyah: $0.int(2)!, juz: $0.int(3)!, hizb: $0.int(4)!, rub: $0.int(5)!))
        }
        var markers: [Marker] = []
        try db.query("SELECT page, kind, value, ayah_id FROM marker WHERE style = ? ORDER BY kind, value", [.text(style)]) {
            markers.append(Marker(page: $0.int(0)!, kind: $0.text(1)!, value: $0.int(2)!, ayahID: $0.int(3)!))
        }
        var meta: [String: String] = [:]
        try db.query("SELECT key, value FROM meta") { meta[$0.text(0)!] = $0.text(1)! }
        var types: [String: Set<String>] = [:]
        try db.query("SELECT kind, typeof(first_word), typeof(last_word), typeof(surah) FROM mushaf_line") {
            types[$0.text(0)!, default: []].formUnion([$0.text(1)!, $0.text(2)!, $0.text(3)!].map { "\($0)" })
        }
        return QuranSQLite(surahs: surahs, ayahs: ayahs, words: words, lines: lines, pages: pages, markers: markers, meta: meta, nullableTypes: types)
    }

    /// Ayah ids matching a search query, folded like the app folds queries: every word in the
    /// word column, or (`stems`) in the word or the stem column.
    static func search(_ query: String, prefix: Bool = false, stems: Bool = false) throws -> [Int] {
        let db = try SQLiteDatabase(path: Paths.quranSQLite.path, readOnly: true)
        let columns = stems ? "{text_norm text_stem}" : "text_norm"
        let match = ArabicNormalizer.normalize(query).split(separator: " ")
            .map { "\(columns) : \"\($0)\"" }.joined(separator: " AND ") + (prefix ? "*" : "")
        var ids: [Int] = []
        try db.query("SELECT rowid FROM ayah_fts WHERE ayah_fts MATCH ? ORDER BY rowid", [.text(match)]) { ids.append($0.int(0)!) }
        return ids
    }

    func id(_ surah: Int, _ ayah: Int) -> Int {
        ayahs.first { ($0.surah, $0.ayah) == (surah, ayah) }!.id
    }

    /// Segments of a text line, built the way the app builds them.
    func segments(_ line: Line) -> [LineSegment<Word>] {
        guard let first = line.firstWord, let last = line.lastWord else { return [] }
        return LineSegmentation.segments(words[(first - 1)...(last - 1)]) { ($0.surah, $0.ayah, $0.isMarker) }
    }
}

@Suite(.enabled(if: Paths.qulBuilt, "build the qul profile first")) struct SQLiteContents {
    let db = QuranSQLite.shared

    @Test func counts() {
        #expect(db.surahs.count == 114)
        #expect(db.surahs.map(\.ayahCount).reduce(0, +) == 6236)
        #expect(db.ayahs.count == 6236)
        #expect(db.ayahs.map(\.id) == Array(1...6236))
        #expect(db.words.count == 83_668)
        #expect(db.words.filter(\.isMarker).count == 6236)
        #expect(db.words.filter { !$0.isMarker }.count == 77_432)
    }

    @Test func ayahsAreInCanonicalOrder() {
        let expected = db.surahs.flatMap { surah in (1...surah.ayahCount).map { "\(surah.id):\($0)" } }
        #expect(db.ayahs.map { "\($0.surah):\($0.ayah)" } == expected)
    }

    @Test func everyAyahEndsWithItsMarker() {
        let byAyah = Dictionary(grouping: db.words, by: \.ayahID)
        for ayah in db.ayahs {
            let words = byAyah[ayah.id] ?? []
            #expect(words.map(\.position) == Array(1...words.count), "\(ayah.surah):\(ayah.ayah)")
            #expect(words.filter(\.isMarker).map(\.position) == [words.count], "\(ayah.surah):\(ayah.ayah)")
            #expect(ayah.textHafs == words.filter { !$0.isMarker }.map(\.hafs).joined(separator: " "))
        }
    }

    @Test func markerTextIsTheAyahNumber() {
        for word in db.words where word.isMarker {
            let digits = String(word.ayah).unicodeScalars.map { Character(Unicode.Scalar($0.value - 0x30 + 0x0660)!) }
            #expect(word.hafs == String(digits), "marker of \(word.surah):\(word.ayah)")
        }
    }

    @Test func everyWordHasAV2Glyph() {
        #expect(db.words.allSatisfy { !$0.glyphV2.isEmpty })
    }

    @Test func surahNamesAndRevelation() {
        #expect(db.surahs.map(\.nameEn) == StaticTables.surahNames.map(\.en))
        #expect(db.surahs.map(\.nameAr) == StaticTables.surahNames.map(\.ar))
        #expect(Set(db.surahs.filter { $0.revelation == "madinah" }.map(\.id)) == StaticTables.madinanSurahs)
    }

    @Test func metaRecordsVerifiedInputHashes() throws {
        #expect(db.meta["schema_version"] == "3")
        #expect(db.meta["styles"] == QuranSQLite.style)
        #expect(db.meta["profile"] == "qul" && (db.meta["capabilities"] ?? "").split(separator: ",").contains("mushafPages"))
        let manifest = try SourceManifest(contentsOf: Paths.sources)
        let recorded = db.meta.filter { $0.key.hasPrefix("sha256:") }
        // Every input that feeds a table is recorded; fonts and packs may add more rows.
        let tableInputs = [
            "layout/qpc-v2-15-lines.db", "script/qpc-hafs-wbw.json", "script/qpc-v2-glyph-wbw.json",
            "script/imlaei-simple.json", "metadata/quran-metadata-surah-name.json", "metadata/quran-metadata-ayah.json",
        ] + ["juz", "hizb", "rub", "manzil", "ruku", "sajda"].map { "metadata/quran-metadata-\($0).json" }
        for input in tableInputs {
            #expect(recorded["sha256:\(input)"] != nil, "\(input) not recorded")
        }
        for (key, hash) in recorded {
            #expect(manifest.sha256ByPath[String(key.dropFirst("sha256:".count))] == hash, "\(key)")
        }
    }
}

@Suite(.enabled(if: Paths.qulBuilt, "build the qul profile first")) struct SQLiteLayout {
    let db = QuranSQLite.shared

    @Test func pageCountsAndLineCounts() {
        let byPage = Dictionary(grouping: db.lines, by: \.page)
        #expect(byPage.keys.sorted() == Array(1...604))
        #expect(db.pages.map(\.page) == Array(1...604))
        let nonStandard = byPage.filter { $0.value.count != 15 }.mapValues(\.count)
        #expect(nonStandard == expectedShortPages)
        for (page, lines) in byPage {
            #expect(lines.map(\.line) == Array(1...lines.count), "page \(page)")
        }
    }

    @Test func emptyStringWordIDsAreStoredAsNull() {
        // The QUL layout uses '' for "not applicable"; quran.sqlite stores NULL.
        #expect(db.nullableTypes["ayah"] == ["integer", "null"])
        #expect(db.nullableTypes["surah_name"] == ["integer", "null"])
        #expect(db.nullableTypes["basmallah"] == ["null"])
        for line in db.lines {
            switch line.kind {
            case "ayah": #expect(line.firstWord != nil && line.lastWord != nil && line.surah == nil)
            case "surah_name": #expect(line.firstWord == nil && line.lastWord == nil && line.surah != nil)
            case "basmallah": #expect(line.firstWord == nil && line.lastWord == nil && line.surah == nil)
            default: Issue.record("unknown kind \(line.kind)")
            }
        }
    }

    @Test func everyWordIsOnExactlyOneLine() {
        var covered = [Int](repeating: 0, count: db.words.count + 1)
        for line in db.lines {
            guard let first = line.firstWord, let last = line.lastWord else { continue }
            for id in first...last { covered[id] += 1 }
        }
        let wrong = covered.indices.dropFirst().filter { covered[$0] != 1 }
        #expect(wrong.isEmpty, "\(wrong.count) words, e.g. \(wrong.prefix(5))")
    }

    @Test func headersAndBasmalas() {
        #expect(db.lines.filter { $0.kind == "surah_name" }.compactMap(\.surah) == Array(1...114))
        #expect(db.lines.filter { $0.kind == "basmallah" }.count == 112)
        let byPage = Dictionary(grouping: db.lines, by: \.page)
        let headerAtBottom = Set(byPage.filter { $0.value.last?.kind == "surah_name" }.keys)
        #expect(headerAtBottom == expectedHeaderAtPageBottom)
    }

    @Test func markerOnlySegmentsOpenTheLine() {
        var count = 0
        for line in db.lines {
            for (index, segment) in db.segments(line).enumerated() where segment.words.isEmpty {
                count += 1
                #expect(index == 0 && segment.endsAyah)
            }
        }
        #expect(count == 573)
    }

    @Test func pageAyahRangesAreContiguous() {
        #expect(db.pages.first?.firstAyah == 1)
        #expect(db.pages.last?.lastAyah == 6236)
        for (previous, page) in zip(db.pages, db.pages.dropFirst()) {
            #expect(page.firstAyah == previous.lastAyah || page.firstAyah == previous.lastAyah + 1, "page \(page.page)")
        }
        let firstPages = (1...30).map { juz in db.pages.first { $0.juz == juz }?.page ?? 0 }
        #expect(firstPages == expectedJuzFirstPages)
    }
}

@Suite(.enabled(if: Paths.qulBuilt, "build the qul profile first")) struct SQLiteMetadata {
    let db = QuranSQLite.shared

    @Test func rangeCounts() {
        #expect(Set(db.ayahs.map(\.juz)) == Set(1...30))
        #expect(Set(db.ayahs.map(\.hizb)) == Set(1...60))
        #expect(Set(db.ayahs.map(\.rub)) == Set(1...240))
        #expect(Set(db.ayahs.map(\.manzil)) == Set(1...7))
        #expect(Set(db.ayahs.map(\.ruku)) == Set(1...558))
    }

    @Test func rangesRunInQuranOrder() {
        for keyPath in [\QuranSQLite.Ayah.juz, \.hizb, \.rub, \.manzil, \.ruku] {
            let values = db.ayahs.map { $0[keyPath: keyPath] }
            #expect(values == values.sorted())
        }
        // Every juz holds two hizbs and every hizb four rubs.
        for ayah in db.ayahs {
            #expect((ayah.hizb + 1) / 2 == ayah.juz, "\(ayah.surah):\(ayah.ayah)")
            #expect((ayah.rub + 3) / 4 == ayah.hizb, "\(ayah.surah):\(ayah.ayah)")
        }
    }

    @Test func juzMatchesTheStaticTable() {
        #expect(db.ayahs.map(\.juz) == db.ayahs.map { StaticTables.juz(surah: $0.surah, ayah: $0.ayah) })
    }

    @Test func fifteenSajdahs() {
        let sajdahs = db.ayahs.filter { $0.sajdah != nil }
        #expect(sajdahs.map { "\($0.surah):\($0.ayah)" } == [
            "7:206", "13:15", "16:50", "17:109", "19:58", "22:18", "22:77", "25:60",
            "27:26", "32:15", "38:24", "41:38", "53:62", "84:21", "96:19",
        ])
        // QUL's values, stored as given.
        #expect(Set(sajdahs.compactMap(\.sajdah)) == ["optional", "required"])
        #expect(sajdahs.filter { $0.sajdah == "required" }.count == 4)
    }

    @Test func everyAyahHasImlaeiText() {
        #expect(db.ayahs.allSatisfy { !$0.textImlaei.isEmpty })
        #expect(db.ayahs[0].textImlaei == "بسم الله الرحمن الرحيم")
    }

    @Test func marginMarkers() {
        let byKind = Dictionary(grouping: db.markers, by: \.kind)
        #expect(byKind["juz"]?.map(\.value) == Array(1...30))
        #expect(byKind["hizb"]?.map(\.value) == Array(1...60))
        #expect(byKind["rub"]?.map(\.value) == Array(1...240))
        #expect(byKind["sajdah"]?.map(\.value) == Array(1...15))
        #expect(byKind["juz"]?.map(\.page) == expectedJuzFirstPages)
        // Golden pages from docs/10: juz 11 starts mid-page 201; page 293 has a sajdah.
        #expect(db.markers.contains { $0.page == 201 && $0.kind == "juz" && $0.value == 11 })
        #expect(db.markers.contains { $0.page == 293 && $0.kind == "sajdah" && $0.ayahID == db.id(17, 109) })
        // Each marker's ayah starts that unit.
        for marker in byKind["rub"] ?? [] {
            #expect(db.ayahs[marker.ayahID - 1].rub == marker.value)
            #expect(marker.ayahID == 1 || db.ayahs[marker.ayahID - 2].rub == marker.value - 1)
        }
    }

    @Test func pagesCarryTheUnitsOfTheirLastAyah() {
        for page in db.pages {
            let last = db.ayahs[page.lastAyah - 1]
            #expect((page.juz, page.hizb, page.rub) == (last.juz, last.hizb, last.rub), "page \(page.page)")
        }
    }
}

@Suite(.enabled(if: Paths.qulBuilt, "build the qul profile first")) struct SQLiteSearch {
    let db = QuranSQLite.shared

    @Test func findsAyahsByNormalizedArabic() throws {
        let rahman = try QuranSQLite.search("الرحمن")
        #expect(rahman.contains(db.id(1, 1)) && rahman.contains(db.id(55, 1)))
        #expect(try QuranSQLite.search("الصمد") == [db.id(112, 2)])
        #expect(try QuranSQLite.search("ٱلصَّمَدُ") == [db.id(112, 2)], "vowelled query")
        // Prefix: also matches الصم ("the deaf", e.g. 8:22).
        let prefixHits = try QuranSQLite.search("الصم", prefix: true)
        #expect(prefixHits.contains(db.id(112, 2)) && prefixHits.contains(db.id(8, 22)))
        #expect(try QuranSQLite.search("مريم").contains(db.id(19, 16)))
        #expect(try QuranSQLite.search("آمنوا").count > 200)
    }

    @Test func multiWordQueriesMatchAllWords() throws {
        #expect(try QuranSQLite.search("الله لا اله الا هو الحي القيوم") == [db.id(2, 255), db.id(3, 2)])
    }

    /// Phase 6.0: the stem column finds words with attached particles; the word column is unchanged.
    @Test func stemColumnFindsAttachedParticles() throws {
        let words = try QuranSQLite.search("الرحمن")
        let withStems = try QuranSQLite.search("الرحمن", stems: true)
        #expect(!words.contains(db.id(19, 26)))
        #expect(withStems.contains(db.id(19, 26)), "للرحمن")
        #expect(Set(words).isSubset(of: withStems))
        // Short words have no stems: ما and لا find exactly what they found before.
        for short in ["ما", "لا"] {
            #expect(try QuranSQLite.search(short, stems: true) == QuranSQLite.search(short))
        }
    }

    /// The stem column holds exactly the stems of the folded Imlaei words.
    @Test func stemColumnMatchesTheStemmer() throws {
        let sqlite = try SQLiteDatabase(path: Paths.quranSQLite.path, readOnly: true)
        var imlaei: [String] = []
        try sqlite.query("SELECT text_imlaei FROM ayah ORDER BY id") { imlaei.append($0.text(0)!) }
        let stems = imlaei.flatMap { ArabicPrefixStemmer.stemText(ArabicNormalizer.normalize($0)).split(separator: " ") }
        // Contentless FTS5: the docsize row holds the token count of each column.
        var tokens = 0
        try sqlite.query("SELECT sz FROM ayah_fts_docsize") { row in
            tokens += Self.varints(row.blob(0)!)[1]
        }
        #expect(tokens == stems.count)
        #expect(stems.count > 10_000)
    }

    /// FTS5 docsize blobs: one varint per column.
    static func varints(_ bytes: [UInt8]) -> [Int] {
        var values: [Int] = []
        var value = 0
        for byte in bytes {
            value = value << 7 | Int(byte & 0x7F)
            if byte & 0x80 == 0 { values.append(value); value = 0 }
        }
        return values
    }

    @Test func indexCoversEveryAyah() throws {
        let sqlite = try SQLiteDatabase(path: Paths.quranSQLite.path, readOnly: true)
        // Contentless FTS5: count the docsize rows, one per indexed ayah.
        #expect(try sqlite.int("SELECT count(*) FROM ayah_fts_docsize") == 6236)
    }
}

/// Checks carried over from the legacy JSON tests (Phase 1.4).
@Suite(.enabled(if: Paths.qulBuilt, "build the qul profile first")) struct SQLiteText {
    let db = QuranSQLite.shared

    /// Every text segment in page order.
    var segments: [LineSegment<QuranSQLite.Word>] { db.lines.flatMap(db.segments) }

    @Test func ayahCountSpotChecks() {
        #expect(db.surahs[0].ayahCount == 7)
        #expect(db.surahs[1].ayahCount == 286)
        #expect(db.surahs[113].ayahCount == 6)
        #expect(db.surahs.filter { $0.revelation == "madinah" }.count == 28)
    }

    @Test func everyAyahAppearsExactlyOnceInOrder() {
        let canonical = db.ayahs.map { "\($0.surah):\($0.ayah)" }
        var seen = Set<String>()
        var appearance: [String] = []
        for segment in segments {
            let key = "\(segment.surah):\(segment.ayah)"
            if seen.insert(key).inserted { appearance.append(key) }
        }
        #expect(appearance == canonical)

        // An ayah's segments are contiguous: it never reappears after another ayah started.
        var previous: String?
        var closed = Set<String>()
        for segment in segments {
            let key = "\(segment.surah):\(segment.ayah)"
            if key != previous {
                #expect(!closed.contains(key), "ayah \(key) is split by another ayah")
                if let previous { closed.insert(previous) }
                previous = key
            }
        }
        // Exactly one end marker per ayah, on the ayah's last segment.
        #expect(segments.filter(\.endsAyah).map { "\($0.surah):\($0.ayah)" } == canonical)
    }

    @Test func pageWordsRebuildAyahText() {
        var rebuilt: [String: [String]] = [:]
        for segment in segments { rebuilt["\(segment.surah):\(segment.ayah)", default: []] += segment.words.map(\.hafs) }
        for ayah in db.ayahs {
            #expect(rebuilt["\(ayah.surah):\(ayah.ayah)"]?.joined(separator: " ") == ayah.textHafs, "\(ayah.surah):\(ayah.ayah)")
        }
    }

    @Test func ayahTextHasNoTrailingNumber() {
        let digits = CharacterSet(charactersIn: "0123456789٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹\u{06DD}")
        let offenders = db.ayahs.filter { $0.textHafs.unicodeScalars.contains(where: digits.contains) }
        #expect(offenders.isEmpty, "\(offenders.prefix(5).map { "\($0.surah):\($0.ayah)" })")
    }

    @Test func noOpenTanween() {
        let open: Set<UInt32> = [0x08F0, 0x08F1, 0x08F2]
        let hits = db.ayahs.filter { $0.textHafs.unicodeScalars.contains { open.contains($0.value) } }
        #expect(hits.isEmpty, "open tanween found in \(hits.map { "\($0.surah):\($0.ayah)" })")
    }

    /// The Unicode renderer draws each end marker as its Hafs text (Arabic-Indic digits): KFGQPC
    /// Hafs turns every one of the 286 ayah numbers into a single ornamented glyph (2.5).
    @Test(.enabled(if: FileManager.default.fileExists(atPath: Paths.kfgqpcFont.path), "KFGQPC font not copied yet"))
    func everyMarkerIsOneGlyphInKFGQPC() throws {
        let descriptor = try #require((CTFontManagerCreateFontDescriptorsFromURL(Paths.kfgqpcFont as CFURL) as? [CTFontDescriptor])?.first)
        let font = CTFontCreateWithFontDescriptor(descriptor, 100, nil)
        let markers = Set(db.words.filter(\.isMarker).map(\.hafs))
        #expect(markers.count == 286)
        for marker in markers {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: marker, attributes: [kCTFontAttributeName as NSAttributedString.Key: font]))
            #expect(CTLineGetGlyphCount(line) == 1, "\(marker)")
        }
    }

    @Test(.enabled(if: FileManager.default.fileExists(atPath: Paths.kfgqpcFont.path), "KFGQPC font not copied yet"))
    func everyCodePointIsInKFGQPCCmap() throws {
        let descriptors = try #require(CTFontManagerCreateFontDescriptorsFromURL(Paths.kfgqpcFont as CFURL) as? [CTFontDescriptor])
        let font = CTFontCreateWithFontDescriptor(try #require(descriptors.first), 12, nil)
        var scalars = Set<Unicode.Scalar>()
        for ayah in db.ayahs { scalars.formUnion(ayah.textHafs.unicodeScalars) }
        let missing = scalars.filter { scalar in
            var utf16 = Array(String(scalar).utf16)
            let count = utf16.count
            var glyphs = [CGGlyph](repeating: 0, count: count)
            return !CTFontGetGlyphsForCharacters(font, &utf16, &glyphs, count)
        }
        #expect(missing.isEmpty, "missing: \(missing.map { String(format: "U+%04X", $0.value) }.sorted())")
    }

    @Test func fatihahIsAloneOnPageOne() {
        let page = db.lines.filter { $0.page == 1 }
        #expect(page.first?.kind == "surah_name" && page.first?.surah == 1)
        #expect(!page.contains { $0.kind == "basmallah" }, "Al-Fatihah's basmala is ayah 1, not a separate line")
        #expect(Set(page.flatMap(db.segments).map(\.surah)) == [1])
        #expect(db.pages[0].firstAyah == 1 && db.pages[0].lastAyah == 7)
    }

    @Test func headerIsFollowedByBasmalaThenAyahOne() {
        #expect(!Dictionary(grouping: db.lines, by: \.page).values.contains { $0.last?.kind == "basmallah" }, "basmala at the bottom of a page")
        for (index, line) in db.lines.enumerated() where line.kind == "surah_name" {
            guard let surah = line.surah else { continue }
            let next = db.lines[index + 1]
            let firstText = surah == 1 || surah == 9 ? next : db.lines[index + 2]
            if surah == 1 || surah == 9 {
                #expect(next.kind == "ayah", "surah \(surah) must not have a basmala line")
            } else {
                #expect(next.kind == "basmallah", "surah \(surah) header not followed by basmala")
            }
            #expect(db.segments(firstText).first.map { "\($0.surah):\($0.ayah)" } == "\(surah):1")
        }
    }

    @Test func juzStartAyahsAreOnTheJuzFirstPages() {
        let pages = db.pages.map(\.juz)
        #expect(pages == pages.sorted())
        for (index, start) in StaticTables.juzStarts.enumerated() {
            let id = db.id(start.surah, start.ayah)
            let page = db.pages.first { $0.firstAyah <= id && id <= $0.lastAyah }?.page
            #expect(page == expectedJuzFirstPages[index], "juz \(index + 1)")
            #expect(db.ayahs[id - 1].juz == index + 1)
        }
    }
}

/// Verified facts about the raw QUL downloads (2026-10-02). Skipped where QuranData/raw is absent.
/// Two tests also read the built database, so it must be built too.
@Suite(.enabled(if: Paths.rawPresent, "QuranData/raw not present"), .enabled(if: Paths.qulBuilt, "build the qul profile first"))
struct RawInputs {
    struct RawWord: Decodable { let id: Int; let surah: String; let ayah: String; let word: String; let text: String }

    @Test func inputsMatchSOURCES() throws {
        let manifest = try SourceManifest(contentsOf: Paths.sources)
        let paths = ["layout/qpc-v2-15-lines.db", "script/qpc-hafs-wbw.json", "script/qpc-v2-glyph-wbw.json",
                     "metadata/quran-metadata-surah-name.json"]
        for path in paths {
            _ = try manifest.verify(path: path, url: Paths.raw.appendingPathComponent(path))
        }
    }

    @Test func wordByWordScriptsShareKeysAndIDs() throws {
        let decoder = JSONDecoder()
        let hafs = try decoder.decode([String: RawWord].self, from: Data(contentsOf: Paths.raw.appendingPathComponent("script/qpc-hafs-wbw.json")))
        let glyph = try decoder.decode([String: RawWord].self, from: Data(contentsOf: Paths.raw.appendingPathComponent("script/qpc-v2-glyph-wbw.json")))
        #expect(hafs.count == 83_668)
        #expect(glyph.count == 83_668)
        #expect(Set(hafs.keys) == Set(glyph.keys))
        #expect(hafs.allSatisfy { key, word in glyph[key]?.id == word.id && "\(word.surah):\(word.ayah):\(word.word)" == key })
        let markers = hafs.values.filter { $0.text.unicodeScalars.allSatisfy { (0x0660...0x0669).contains($0.value) } }
        #expect(markers.count == 6236)
    }

    @Test func layoutUsesEmptyStringsNotNull() throws {
        let layout = try SQLiteDatabase(path: Paths.raw.appendingPathComponent("layout/qpc-v2-15-lines.db").path, readOnly: true)
        #expect(try layout.int("SELECT count(*) FROM pages WHERE line_type IN ('surah_name', 'basmallah') AND first_word_id = ''") == 226)
        #expect(try layout.int("SELECT count(*) FROM pages WHERE first_word_id IS NULL") == 0)
    }

    @Test func metadataShapesAndCounts() throws {
        let expected = [("juz", 30), ("hizb", 60), ("rub", 240), ("manzil", 7), ("ruku", 558)]
        for (kind, count) in expected {
            let data = try Data(contentsOf: Paths.raw.appendingPathComponent("metadata/quran-metadata-\(kind).json"))
            let table = try #require(try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])
            #expect(table.count == count, "\(kind)")
            #expect(table.values.allSatisfy { $0["first_verse_key"] is String && $0["last_verse_key"] is String && $0["verse_mapping"] is [String: String] }, "\(kind)")
        }
        struct Sajda: Decodable { let verse_key: String; let sajdah_type: String }
        let sajda = try JSONDecoder().decode([String: Sajda].self, from: Data(contentsOf: Paths.raw.appendingPathComponent("metadata/quran-metadata-sajda.json")))
        #expect(sajda.count == 15)
    }

    @Test func imlaeiIsKeyedBySurahAyah() throws {
        struct Entry: Decodable { let verse_key: String; let text: String }
        let imlaei = try JSONDecoder().decode([String: Entry].self, from: Data(contentsOf: Paths.raw.appendingPathComponent("script/imlaei-simple.json")))
        #expect(imlaei.count == 6236)
        #expect(imlaei.allSatisfy { $0.key == $0.value.verse_key && !$0.value.text.isEmpty })
    }

    @Test func wordsWithSpacesAndTheOneWordCountDifference() throws {
        // Spaces inside a word: the rub el-hizb sign before it ("۞ …"), the sajdah sign after
        // it ("… ۩", 9 of the 15 sajdahs), and إِلۡ يَاسِينَ (37:130:3). QUL's ayah metadata
        // counts the latter as two words: its only words_count difference.
        let hafs = try JSONDecoder().decode([String: RawWord].self, from: Data(contentsOf: Paths.raw.appendingPathComponent("script/qpc-hafs-wbw.json")))
        let spaced = hafs.filter { $0.value.text.contains(" ") }
        #expect(spaced.count == 209)
        #expect(spaced.filter { $0.value.text.hasSuffix(" ۩") }.count == 9)
        #expect(spaced.filter { !$0.value.text.hasPrefix("۞ ") && !$0.value.text.hasSuffix(" ۩") }.map(\.key) == ["37:130:3"])

        struct Meta: Decodable { let verse_key: String; let words_count: Int }
        let meta = try JSONDecoder().decode([String: Meta].self, from: Data(contentsOf: Paths.raw.appendingPathComponent("metadata/quran-metadata-ayah.json")))
        let db = QuranSQLite.shared
        let counts = Dictionary(grouping: db.words.filter { !$0.isMarker }, by: { "\($0.surah):\($0.ayah)" }).mapValues(\.count)
        #expect(meta.values.filter { counts[$0.verse_key] != $0.words_count }.map(\.verse_key) == ["37:130"])
    }

    @Test func everyV2GlyphIsInItsPageFont() throws {
        let db = QuranSQLite.shared
        var missing: [String] = []
        for (page, lines) in Dictionary(grouping: db.lines, by: \.page) {
            let url = Paths.raw.appendingPathComponent("fonts/v2/p\(page).ttf")
            let descriptors = try #require(CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])
            let font = CTFontCreateWithFontDescriptor(try #require(descriptors.first), 12, nil)
            for line in lines {
                guard let first = line.firstWord, let last = line.lastWord else { continue }
                for word in db.words[(first - 1)...(last - 1)] {
                    var utf16 = Array(word.glyphV2.utf16)
                    let count = utf16.count
                    var glyphs = [CGGlyph](repeating: 0, count: count)
                    if !CTFontGetGlyphsForCharacters(font, &utf16, &glyphs, count) {
                        missing.append("p\(page) word \(word.id)")
                    }
                }
            }
        }
        #expect(missing.isEmpty, "\(missing.count) glyphs missing, e.g. \(missing.prefix(5))")
    }

    /// QUL's header values end in a space, except one.
    @Test func surahHeaderLigaturesHaveTrailingSpaces() throws {
        let raw = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: Paths.raw.appendingPathComponent("fonts/headers/surah-header-ligatures.json")))
        #expect(raw.count == 114)
        #expect(raw.values.filter { $0.hasSuffix(" ") }.count == 113)
    }

    @Test func quLSpellsSixArabicSurahNamesDifferently() throws {
        struct Name: Decodable { let name_arabic: String }
        let qul = try JSONDecoder().decode([String: Name].self, from: Data(contentsOf: Paths.raw.appendingPathComponent("metadata/quran-metadata-surah-name.json")))
        let different = (1...114).filter { qul[String($0)]?.name_arabic != StaticTables.surahNames[$0 - 1].ar }
        #expect(different == [14, 34, 76, 78, 82, 84])
    }
}

/// QUL ligature tables (2.1) and the header/name/common fonts copied into the app bundle.
@Suite(.enabled(if: Paths.qulBuilt, "build the qul profile first")) struct SQLiteFontLigatures {
    static let table: [String: [String: String]] = {
        var result: [String: [String: String]] = [:]
        do {
            let db = try SQLiteDatabase(path: Paths.quranSQLite.path, readOnly: true)
            try db.query("SELECT font, name, value FROM font_ligature") { result[$0.text(0)!, default: [:]][$0.text(1)!] = $0.text(2)! }
        } catch { fatalError("font_ligature: \(error)") }
        return result
    }()

    static func font(_ file: String, size: CGFloat = 100) throws -> CTFont {
        let url = Paths.bundledFonts.appendingPathComponent(file)
        let descriptors = try #require(CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])
        return CTFontCreateWithFontDescriptor(try #require(descriptors.first), size, nil)
    }

    /// Glyphs of `text` shaped in `font`, with their advances.
    static func shape(_ text: String, _ font: CTFont) -> [(glyph: CGGlyph, advance: CGFloat)] {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [kCTFontAttributeName as NSAttributedString.Key: font]))
        var result: [(CGGlyph, CGFloat)] = []
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var advances = [CGSize](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(), &glyphs)
            CTRunGetAdvances(run, CFRange(), &advances)
            result += zip(glyphs, advances.map(\.width)).map { ($0, $1) }
        }
        return result
    }

    @Test func surahTablesCoverEverySurahOnce() {
        let keys = Set((1...114).map { "surah-\($0)" })
        for font in ["surah-header", "surah-name-v2"] {
            let entries = Self.table[font] ?? [:]
            #expect(Set(entries.keys) == keys, "\(font)")
            #expect(Set(entries.values).count == 114, "\(font)")
            #expect(entries.values.allSatisfy { $0 == $0.trimmingCharacters(in: .whitespaces) }, "\(font): untrimmed")
        }
        #expect(Self.table["surah-name-v2"]?["surah-7"] == "surah007")
        #expect(Self.table["surah-header"]?["surah-1"]?.unicodeScalars.map(\.value) == [0xFC45])
    }

    @Test func bundledFontsAreTheVerifiedQULFiles() throws {
        let manifest = try SourceManifest(contentsOf: Paths.sources)
        for name in ["surah-header.ttf", "surah-name-v2.ttf", "quran-common.ttf"] {
            let hash = try SourceManifest.sha256(of: Paths.bundledFonts.appendingPathComponent(name))
            #expect(manifest.sha256ByPath["fonts/headers/\(name)"] == hash, "\(name)")
        }
        #expect(!FileManager.default.fileExists(atPath: Paths.bundledFonts.appendingPathComponent("SurahNames.ttf").path))
    }

    @Test func postScriptNames() throws {
        #expect(CTFontCopyPostScriptName(try Self.font("surah-header.ttf")) as String == "QCF_SurahHeader_COLOR")
        #expect(CTFontCopyPostScriptName(try Self.font("surah-name-v2.ttf")) as String == "surah-name-v2")
        #expect(CTFontCopyPostScriptName(try Self.font("quran-common.ttf")) as String == "quran-common")
    }

    /// One colour glyph per surah, all the same width: 3.30 em (the app sizes headers with it).
    @Test func everySurahHeaderIsOneGlyphOfTheSameWidth() throws {
        let font = try Self.font("surah-header.ttf")
        for surah in 1...114 {
            let shaped = Self.shape(try #require(Self.table["surah-header"]?["surah-\(surah)"]), font)
            #expect(shaped.count == 1 && shaped[0].glyph != 0, "surah \(surah)")
            #expect(abs((shaped.first?.advance ?? 0) / 100 - 3.30) < 0.01, "surah \(surah): \(shaped.first?.advance ?? 0)")
        }
    }

    @Test func everySurahNameDrawsOneInkedGlyph() throws {
        let font = try Self.font("surah-name-v2.ttf")
        var multiGlyph: [Int] = []
        for surah in 1...114 {
            let shaped = Self.shape(try #require(Self.table["surah-name-v2"]?["surah-\(surah)"]), font)
            if shaped.count != 1 { multiGlyph.append(surah) }
            // Whatever the rule, exactly one glyph has width: the name.
            #expect(shaped.filter { $0.advance > 0 }.count == 1, "surah \(surah)")
        }
        #expect(multiGlyph == expectedMultiGlyphSurahNames)
    }

    @Test func juzNamesAreInQuranCommon() throws {
        let font = try Self.font("quran-common.ttf")
        let entries = Self.table["quran-common"] ?? [:]
        for juz in 1...30 {
            let value = try #require(entries["juz-\(juz)-name"])
            #expect(value == String(format: "j%03d", juz))
            #expect(Self.shape(value, font).filter { $0.advance > 0 }.count == 1, "juz \(juz)")
        }
    }
}

/// The 604 V2 page fonts the pipeline copies into the app (git-ignored, so skipped until copied).
@Suite(.enabled(if: FileManager.default.fileExists(atPath: Paths.pageFonts.appendingPathComponent("p1.ttf").path), "V2 page fonts not copied yet"))
struct BundledPageFonts {
    let folder = Paths.pageFonts

    @Test func folderMatchesTheManifestFileByFile() throws {
        let manifest = try String(contentsOf: Paths.quranData.appendingPathComponent("fonts-v2.sha256"), encoding: .utf8)
        var expected: [String: String] = [:]
        for line in manifest.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            expected[String(parts[1].trimmingCharacters(in: .whitespaces).split(separator: "/").last!)] = String(parts[0])
        }
        #expect(expected.count == 604)
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }
        #expect(Set(files) == Set(expected.keys))
        for name in files.sorted() {
            #expect(try SourceManifest.sha256(of: folder.appendingPathComponent(name)) == expected[name], "\(name)")
        }
    }

    @Test func postScriptNamesFollowThePageNumber() throws {
        for page in 1...604 {
            let url = folder.appendingPathComponent("p\(page).ttf")
            let descriptor = try #require((CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first)
            #expect(CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String == String(format: "QCF2%03d", page))
        }
    }
}

/// docs/03 step 9: size report and budget (2.7).
@Suite struct SizeReporting {
    @Test func groupsSubfoldersAndCompresses() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sizes-\(UUID().uuidString)")
        let pack = root.appendingPathComponent("Fonts/pack")
        try FileManager.default.createDirectory(at: pack, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 65, count: 100_000).write(to: root.appendingPathComponent("a.sqlite"))
        try Data(repeating: 66, count: 10_000).write(to: root.appendingPathComponent("Fonts/b.ttf"))
        for i in 1...3 { try Data(repeating: UInt8(i), count: 5_000).write(to: pack.appendingPathComponent("p\(i).ttf")) }
        let report = try SizeReport(resources: root)
        // Items are prefixed by the measured folder's name. Files in a subfolder are grouped by that
        // subfolder, so b.ttf is an item of its own folder ("Fonts/"), not of its file.
        let name = root.lastPathComponent
        #expect(Set(report.items.map(\.path)) == ["\(name)/a.sqlite", "\(name)/Fonts/", "\(name)/Fonts/pack/"])
        #expect(report.items.first { $0.path == "\(name)/Fonts/pack/" }?.files == 3)
        #expect(report.rawBytes == 125_000)
        #expect(report.compressedBytes < report.rawBytes / 10)   // repeated bytes deflate well
        #expect(report.violations(budgetCompressedMB: 1, budgetInstalledMB: 1).isEmpty)
        #expect(report.violations(budgetCompressedMB: 0, budgetInstalledMB: 0).count == 2)
    }

    /// The bundle the app ships fits the docs/03 budget (needs the built qul profile and the copied V2 page fonts).
    @Test(.enabled(if: Paths.qulBuilt, "build the qul profile first"),
          .enabled(if: FileManager.default.fileExists(atPath: Paths.pageFonts.appendingPathComponent("p1.ttf").path), "V2 page fonts not copied yet"))
    func shippedDataFitsTheBudget() throws {
        let report = try SizeReport(folders: [Paths.out.appendingPathComponent("qul"), Paths.quranData.appendingPathComponent("Fonts")])
        #expect(report.violations(budgetCompressedMB: 200, budgetInstalledMB: 400).isEmpty)
        #expect(report.items.first { $0.path == "Fonts/madaniV2/" }?.files == 604)
    }
}

@Suite struct SourceManifestParsing {
    @Test func parsesHashRowsAndVerifies() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("manifest-\(UUID().uuidString).txt")
        try Data("hello".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let hash = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        let manifest = SourceManifest(markdown: """
            | Resource | File | SHA-256 | License |
            |---|---|---|---|
            | Greeting | `x/hello.txt` | \(hash) | none |
            | Other | `x/other.txt` | \(String(repeating: "0", count: 64)) | none |
            """)
        #expect(manifest.sha256ByPath.count == 2)
        #expect(try manifest.verify(path: "x/hello.txt", url: file) == hash)
        #expect(throws: SourceManifest.VerificationError.notListed("x/missing.txt")) {
            try manifest.verify(path: "x/missing.txt", url: file)
        }
        #expect(throws: SourceManifest.VerificationError.mismatch(path: "x/other.txt", expected: String(repeating: "0", count: 64), actual: hash)) {
            try manifest.verify(path: "x/other.txt", url: file)
        }
    }
}
