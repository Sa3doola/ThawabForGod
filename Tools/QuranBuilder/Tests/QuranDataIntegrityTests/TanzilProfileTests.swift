// The tanzil profile against the database the app ships today.
//
// Until M3 swaps it in, `ThawabForGod/Resources/Corpus/quran.sqlite` (built by the retiring
// `build_quran_db.py`) is the reference: the new build must carry the same Quran, verse for verse
// and byte for byte, with the same divisions, and must find the same verses for the same words.

import ArabicText
import Foundation
import QuranDataModel
import Testing

@Suite(.enabled(if: Paths.tanzilBuilt, "build the tanzil profile first"))
struct TanzilProfile {
    let db: SQLiteDatabase
    let legacy: SQLiteDatabase

    init() throws {
        db = try SQLiteDatabase(path: Paths.tanzilSQLite.path, readOnly: true)
        legacy = try SQLiteDatabase(path: Paths.legacyQuranSQLite.path, readOnly: true)
    }

    private func meta(_ key: String) throws -> String? {
        guard case .text(let value) = try db.scalar("SELECT value FROM meta WHERE key = ?", [.text(key)]) else { return nil }
        return value
    }

    // MARK: The whole Quran, in the shared schema

    @Test func holdsEverySurahAndAyahInOrder() throws {
        #expect(try db.int("SELECT count(*) FROM surah") == 114)
        #expect(try db.int("SELECT count(*) FROM ayah") == 6236)
        #expect(try db.int("SELECT count(*) FROM ayah WHERE id <> (SELECT count(*) FROM ayah b WHERE b.surah < ayah.surah OR (b.surah = ayah.surah AND b.ayah <= ayah.ayah))") == 0)
        #expect(try db.int("SELECT count(*) FROM ayah a JOIN surah s ON s.id = a.surah WHERE a.ayah > s.ayah_count") == 0)
    }

    @Test func saysWhatItIsAndLeavesTheLayoutTablesEmpty() throws {
        #expect(try meta("profile") == "tanzil")
        #expect(try meta("schema_version") == "3")
        #expect(try meta("generator") == "Tools/QuranBuilder")
        // Text and search only: the app hides Mushaf mode and the Page tab on this build.
        #expect(try meta("capabilities") == "text")
        for table in ["word", "mushaf_line", "mushaf_page", "marker", "font_ligature"] {
            #expect(try db.int("SELECT count(*) FROM \(table)") == 0, "\(table)")
        }
    }

    /// Tanzil's terms ask for their notice to be reproduced in derived files; this is one.
    @Test func carriesBothTanzilNotices() throws {
        for id in ["tanzil-uthmani", "tanzil-simple-clean"] {
            #expect(try meta("source:\(id):notice")?.contains("Tanzil Project") == true, "\(id)")
            #expect(try meta("source:\(id):licence") == "Creative Commons Attribution 3.0", "\(id)")
        }
        #expect(try meta("digest:tanzil-uthmani") == "36da55e256f54f4838b6fa1c78781734346c8d9ffde52daf5a3cbfa32626a08c")
        #expect(try meta("digest:tanzil-simple-clean") == "7c74ab21103b99d8d0bacd94e7c11f5f5855b22d3f0d32e1f09fb6cd73764b58")
    }

    // MARK: The same Quran as today

    /// The text of the Quran is never edited: what is drawn must be byte-identical to what the app
    /// draws today, the basmala lifted off verse 1 the same way.
    @Test func textIsByteIdenticalToTodaysCorpus() throws {
        var today: [String: String] = [:]
        try legacy.query("SELECT surah_id, number, text FROM verse") { row in
            today["\(row.int(0)!):\(row.int(1)!)"] = row.text(2)
        }
        #expect(today.count == 6236)

        var differing: [String] = []
        try db.query("SELECT surah, ayah, text_hafs FROM ayah") { row in
            let key = "\(row.int(0)!):\(row.int(1)!)"
            if today[key] != row.text(2) { differing.append(key) }
        }
        #expect(differing.isEmpty, "differs at \(differing.prefix(5))")
    }

    @Test func divisionsAndSajdahsMatchTodaysCorpus() throws {
        var today: [String: [Int]] = [:]
        var sajdahs: [String: String] = [:]
        try legacy.query("SELECT surah_id, number, juz, hizb, rub_el_hizb, sajda FROM verse") { row in
            let key = "\(row.int(0)!):\(row.int(1)!)"
            today[key] = [row.int(2)!, row.int(3)!, row.int(4)!]
            if let sajda = row.text(5) { sajdahs[key] = sajda }
        }

        var differing: [String] = []
        var built: [String: String] = [:]
        try db.query("SELECT surah, ayah, juz, hizb, rub, sajdah FROM ayah") { row in
            let key = "\(row.int(0)!):\(row.int(1)!)"
            if today[key] != [row.int(2)!, row.int(3)!, row.int(4)!] { differing.append(key) }
            if let sajdah = row.text(5) { built[key] = sajdah }
        }
        #expect(differing.isEmpty, "differs at \(differing.prefix(5))")

        // Same fifteen verses; Tanzil's words translated into the schema's (QUL's).
        let translated = sajdahs.mapValues { $0 == "obligatory" ? "required" : "optional" }
        #expect(built == translated)
        #expect(built.values.filter { $0 == "required" }.count == 4)
    }

    @Test func the112SurahsThatOpenWithTheBasmalaSaySo() throws {
        #expect(try db.int("SELECT count(*) FROM surah WHERE bismillah_pre = 1") == 112)
        #expect(try db.int("SELECT count(*) FROM surah WHERE bismillah_pre = 0 AND id IN (1, 9)") == 2)
        // Lifted, not dropped: verse 1 of Al-Baqara is the letters, not the basmala.
        guard case .text(let text) = try db.scalar("SELECT text_hafs FROM ayah WHERE surah = 2 AND ayah = 1") else {
            Issue.record("no 2:1"); return
        }
        #expect(text == "الٓمٓ")
    }

    // MARK: The same search as today

    /// The search text is folded by `ArabicNormalizer` now, and by Python's `normalize()` before.
    /// Over the whole Simple Clean text the two must agree, verse for verse.
    @Test func everyVerseFoldsAsItDidBefore() throws {
        var today: [String: String] = [:]
        try legacy.query("SELECT surah_id, number, text_normalized FROM verse") { row in
            today["\(row.int(0)!):\(row.int(1)!)"] = row.text(2)
        }

        var differing: [String] = []
        try db.query("SELECT surah, ayah, text_imlaei FROM ayah") { row in
            let key = "\(row.int(0)!):\(row.int(1)!)"
            if today[key] != ArabicNormalizer.normalize(row.text(2)!) { differing.append(key) }
        }
        #expect(differing.isEmpty, "differs at \(differing.prefix(5))")
    }

    /// The same words find the same verses in both indexes. The new index's stem column is left
    /// out (`text_norm :`), since finding للرحمن under الرحمن is new and deliberate.
    @Test func theSameQueriesFindTheSameVerses() throws {
        var words: [String] = ["الرحمن", "السماوات", "موسي", "فرعون", "الحمد لله", "بسم الله", "يا ايها الذين امنوا"]
        // A deterministic spread of the corpus: the first and last word of every 25th verse.
        try legacy.query("SELECT text_normalized FROM verse WHERE rowid % 25 = 0") { row in
            let verse = row.text(0)!.split(separator: " ")
            words += [verse.first, verse.last].compactMap { $0.map(String.init) }
        }

        var differing: [String] = []
        for word in Set(words) {
            let phrase = "\"\(ArabicNormalizer.words(in: word).joined(separator: " "))\""
            var built = Set<String>(), today = Set<String>()
            try db.query("SELECT a.surah, a.ayah FROM ayah_fts JOIN ayah a ON a.id = ayah_fts.rowid WHERE ayah_fts MATCH ?",
                         [.text("text_norm : \(phrase)")]) { built.insert("\($0.int(0)!):\($0.int(1)!)") }
            try legacy.query("SELECT v.surah_id, v.number FROM verse_fts JOIN verse v ON v.rowid = verse_fts.rowid WHERE verse_fts MATCH ?",
                             [.text(phrase)]) { today.insert("\($0.int(0)!):\($0.int(1)!)") }
            if built != today { differing.append(word) }
        }
        #expect(words.count > 400)
        #expect(differing.isEmpty, "differs for \(differing.prefix(5))")
    }

    /// The stem column is what the tanzil build adds: a word with an attached particle is found
    /// under its bare form, as Mushaf's search finds it (19:26 للرحمن).
    @Test func theStemColumnFindsAttachedParticles() throws {
        let plain = try db.int("SELECT count(*) FROM ayah_fts WHERE ayah_fts MATCH 'text_norm : \"الرحمن\"'") ?? 0
        let withStems = try db.int("SELECT count(*) FROM ayah_fts WHERE ayah_fts MATCH '\"الرحمن\"'") ?? 0
        #expect(withStems > plain)
        #expect(try db.int("""
            SELECT count(*) FROM ayah_fts JOIN ayah a ON a.id = ayah_fts.rowid
            WHERE ayah_fts MATCH 'text_stem : "الرحمن"' AND a.surah = 19 AND a.ayah = 26
            """) == 1)
    }
}

/// The two profiles fill one schema, so what they share must read the same: a surah is named and
/// placed identically whichever build the app was given.
@Suite(.enabled(if: Paths.tanzilBuilt && Paths.qulBuilt, "build both profiles first"))
struct ProfilesAgree {
    @Test func surahsAreNamedAndPlacedAlike() throws {
        func surahs(_ url: URL) throws -> [String] {
            var rows: [String] = []
            try SQLiteDatabase(path: url.path, readOnly: true)
                .query("SELECT id, name_ar, name_en, ayah_count, revelation, bismillah_pre FROM surah ORDER BY id") { row in
                    rows.append([0, 1, 2, 3, 4, 5].map { row.text($0) ?? row.int($0).map(String.init) ?? "" }.joined(separator: "|"))
                }
            return rows
        }
        #expect(try surahs(Paths.tanzilSQLite) == surahs(Paths.quranSQLite))
    }

    @Test func juzAndSajdahsAgreeAyahForAyah() throws {
        func rows(_ url: URL) throws -> [String] {
            var rows: [String] = []
            try SQLiteDatabase(path: url.path, readOnly: true)
                .query("SELECT surah, ayah, juz, ifnull(sajdah, '') FROM ayah ORDER BY id") { row in
                    rows.append("\(row.int(0)!):\(row.int(1)!) \(row.int(2)!) \(row.text(3) ?? "")")
                }
            return rows
        }
        #expect(try rows(Paths.tanzilSQLite) == rows(Paths.quranSQLite))
    }

    /// The two sources' divisions, as the Corpus README records them: identical hizb and manzil,
    /// one rub el hizb boundary apart (quarter 106 opens at 15:49 in QUL, 15:50 in Tanzil). A change
    /// in either source shows up here before it shows up as a reader sent to the wrong quarter.
    @Test func theDivisionsDifferOnlyWhereTheREADMESaysTheyDo() throws {
        let db = try SQLiteDatabase(path: Paths.tanzilSQLite.path, readOnly: true)
        try db.execute("ATTACH DATABASE '\(Paths.quranSQLite.path)' AS qul")
        func differing(_ column: String) throws -> [String] {
            var keys: [String] = []
            try db.query("SELECT a.surah, a.ayah FROM ayah a JOIN qul.ayah b USING (id) WHERE a.\(column) <> b.\(column)") {
                keys.append("\($0.int(0)!):\($0.int(1)!)")
            }
            return keys
        }
        #expect(try differing("hizb").isEmpty)
        #expect(try differing("manzil").isEmpty)
        #expect(try differing("rub") == ["15:49"])
    }
}
