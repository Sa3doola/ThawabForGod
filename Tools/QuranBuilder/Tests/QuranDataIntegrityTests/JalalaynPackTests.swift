// The Jalalayn pack against the tafsir the app ships today, and the contract every pack keeps so
// the app can find it without a manifest (T15, T16).

import Foundation
import QuranDataModel
import Testing

@Suite(.enabled(if: Paths.jalalaynBuilt && Paths.tanzilBuilt, "build the tanzil profile first"))
struct JalalaynPack {
    let pack: SQLiteDatabase
    /// "s:a" by global ayah id, from the tanzil database the pack was joined against.
    let keyOfAyah: [Int: String]
    /// Today's notes, by "s:a".
    let today: [String: String]

    init() throws {
        pack = try SQLiteDatabase(path: Paths.packs("tanzil").appendingPathComponent("tafsir-ar-jalalayn.sqlite").path, readOnly: true)

        var keys: [Int: String] = [:]
        try SQLiteDatabase(path: Paths.tanzilSQLite.path, readOnly: true)
            .query("SELECT id, surah, ayah FROM ayah") { keys[$0.int(0)!] = "\($0.int(1)!):\($0.int(2)!)" }
        keyOfAyah = keys

        var notes: [String: String] = [:]
        try SQLiteDatabase(path: Paths.legacyTafsirSQLite.path, readOnly: true)
            .query("SELECT surah_id, number, text FROM tafsir WHERE edition_id = 'jalalayn'") {
                notes["\($0.int(0)!):\($0.int(1)!)"] = $0.text(2)!
            }
        today = notes
    }

    /// The inverse of `MirroredTafsirMarkup.html`: the paragraph unwrapped, line breaks back, the
    /// three escapes undone.
    static func text(fromHTML html: String) -> String {
        var text = html
        if text.hasPrefix("<p>") { text.removeFirst(3) }
        if text.hasSuffix("</p>") { text.removeLast(4) }
        return text.replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func notes() throws -> [String: String] {
        var notes: [String: String] = [:]
        try pack.query("SELECT ayah_id, html FROM tafsir") { notes[keyOfAyah[$0.int(0)!]!] = $0.text(1) }
        return notes
    }

    // MARK: Silence

    /// The heart of T16: the ayahs the two Jalals pass over have no row — exactly the ones that have
    /// none today, so the app's "no note here" lands on the same 226 verses.
    @Test func theSilentAyahsAreTodaysSilentVerses() throws {
        let built = Set(try notes().keys)
        let all = Set(keyOfAyah.values)
        #expect(all.count == 6236)
        #expect(all.subtracting(built) == all.subtracting(Set(today.keys)))
        #expect(all.subtracting(built).count == 226)
    }

    /// The verses the app's own tafsir tests name as passed over.
    @Test(arguments: ["2:82", "2:274", "2:277", "3:2", "5:10"])
    func aVerseTheCommentaryPassesOverHasNoRow(_ key: String) throws {
        #expect(try notes()[key] == nil)
    }

    /// No groups: every note is its own owner, so nothing can stand in for a missing one.
    @Test func everyRowIsItsOwnGroupWithText() throws {
        #expect(try pack.int("SELECT count(*) FROM tafsir") == 6010)
        #expect(try pack.int("SELECT count(*) FROM tafsir WHERE group_ayah_id <> ayah_id OR html IS NULL OR html = ''") == 0)
        #expect(try pack.int("SELECT count(*) FROM pack_fts") == 6010)
    }

    // MARK: The same words

    /// The commentary is no more edited than the Quran: undoing the markup gives today's note back,
    /// byte for byte, for every one of the 6,010.
    @Test func everyNoteIsTodaysTextByteForByte() throws {
        let built = try notes()
        var differing: [String] = []
        for (key, html) in built where Self.text(fromHTML: html) != today[key] { differing.append(key) }
        #expect(built.count == today.count)
        #expect(differing.isEmpty, "differs at \(differing.sorted().prefix(5))")
    }

    @Test func notesThatRunToSeveralParagraphsKeepTheirBreaks() throws {
        let built = try notes()
        #expect(built.values.filter { $0.contains("<br>") }.count == today.values.filter { $0.contains("\n") }.count)
        #expect(try #require(built["2:1"]).contains("<br>"))
    }

    // MARK: Provenance

    @Test func thePackSaysWhatItIsAndWhyItMayBeHere() throws {
        var row: [String] = []
        try pack.query("SELECT id, kind, language, direction, license, name_ar, author_ar FROM pack") { r in
            row = (0..<7).map { r.text($0) ?? "" }
        }
        #expect(row[0] == "ar-jalalayn")
        #expect(row[1] == "tafsir")
        #expect(row[2] == "ar")
        #expect(row[3] == "rtl")
        #expect(row[4].contains("Public domain"))
        #expect(row[5] == "تفسير الجلالين")
        #expect(!row[6].isEmpty)
    }

    @Test func theMetaRecordsThePins() throws {
        func meta(_ key: String) throws -> String? {
            guard case .text(let value) = try pack.scalar("SELECT value FROM meta WHERE key = ?", [.text(key)]) else { return nil }
            return value
        }
        #expect(try meta("digest:notes") == "15f89b2781e2b8e804d2c6dc837ef892ea206c4f6f91eed9b7daf5af69beedc2")
        #expect(try meta("silent_ayahs") == "226")
        #expect(try meta("schema_version") == "2")
    }
}

/// What the app relies on to find packs with no manifest: the file prefix names the kind, and the
/// file describes itself in both languages. Checked for every profile that has been built.
struct PackDiscovery {
    static let prefixes = ["translation-": "translation", "tafsir-": "tafsir", "surah-info-": "surah-info"]
    static var builtProfiles: [String] {
        ["tanzil", "qul"].filter { FileManager.default.fileExists(atPath: Paths.packs($0).path) }
    }

    @Test(.enabled(if: !builtProfiles.isEmpty, "build a profile first"), arguments: builtProfiles)
    func everyPackIsFoundByItsPrefixAndDescribesItself(_ profile: String) throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: Paths.packs(profile).path)
            .filter { !$0.hasPrefix(".") }.sorted()
        #expect(!files.isEmpty)

        for file in files {
            #expect(file.hasSuffix(".sqlite"), "\(file): only packs live in Packs/")
            let kind = Self.prefixes.first { file.hasPrefix($0.key) }?.value
            #expect(kind != nil, "\(file): no kind prefix")

            let db = try SQLiteDatabase(path: Paths.packs(profile).appendingPathComponent(file).path, readOnly: true)
            #expect(try db.int("SELECT count(*) FROM pack") == 1, "\(file)")
            try db.query("SELECT kind, name, author, name_ar, author_ar FROM pack") { row in
                #expect(row.text(0) == kind, "\(file): pack.kind")
                for column in Int32(1)...4 { #expect(!(row.text(column) ?? "").isEmpty, "\(file): column \(column)") }
            }
            guard case .text(let version) = try db.scalar("SELECT value FROM meta WHERE key = 'schema_version'") else {
                Issue.record("\(file): no schema_version"); continue
            }
            #expect(version == "2", "\(file)")
        }
    }

    /// The report is written for people, not read by the app — but it must describe what is
    /// actually in the folder, file for file and hash for hash.
    @Test(.enabled(if: !builtProfiles.isEmpty, "build a profile first"), arguments: builtProfiles)
    func theReportDescribesTheFolder(_ profile: String) throws {
        struct Report: Decodable { struct Entry: Decodable { let file: String; let sha256: String }; let packs: [Entry] }
        let report = try JSONDecoder().decode(Report.self, from: Data(contentsOf: Paths.packReport(profile)))
        let files = try FileManager.default.contentsOfDirectory(atPath: Paths.packs(profile).path).filter { !$0.hasPrefix(".") }
        #expect(Set(report.packs.map(\.file)) == Set(files))
        for entry in report.packs {
            #expect(try SourceManifest.sha256(of: Paths.packs(profile).appendingPathComponent(entry.file)) == entry.sha256, "\(entry.file)")
        }
        #expect(!FileManager.default.fileExists(atPath: Paths.packs(profile).appendingPathComponent("manifest.json").path))
    }

    /// Every QUL pack covers the whole Quran: every ayah has a translation, every ayah of a tafsir
    /// belongs to a group whose owner has text, every surah has an introduction.
    @Test(.enabled(if: Paths.qulBuilt && FileManager.default.fileExists(atPath: Paths.packs("qul").path), "build the qul profile first"))
    func everyQULPackCoversTheQuran() throws {
        func db(_ file: String) throws -> SQLiteDatabase {
            try SQLiteDatabase(path: Paths.packs("qul").appendingPathComponent(file).path, readOnly: true)
        }
        #expect(try db("translation-en-sahih-international.sqlite").int("SELECT count(*) FROM translation WHERE text <> ''") == 6236)
        for file in ["tafsir-ar-muyassar.sqlite", "tafsir-en-mukhtasar.sqlite"] {
            let tafsir = try db(file)
            #expect(try tafsir.int("SELECT count(*) FROM tafsir") == 6236, "\(file)")
            #expect(try tafsir.int("""
                SELECT count(*) FROM tafsir t JOIN tafsir owner ON owner.ayah_id = t.group_ayah_id
                WHERE owner.html IS NULL OR owner.html = ''
                """) == 0, "\(file)")
        }
        #expect(try db("surah-info-en.sqlite").int("SELECT count(*) FROM surah_info") == 114)
    }
}
