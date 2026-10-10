// Phase 3.1: translation packs, read from the qul profile's pack folder (docs/03 pack schema).
// Tafsir packs: TafsirPackTests.swift.

import Foundation
import QuranDataModel
import Testing

/// The pack report, `Paths.packReport("qul")`, as the pack entries describe themselves. The report
/// is written beside the Packs folder, not inside it.
struct ManifestFile: Decodable {
    struct Entry: Decodable {
        let id, kind, language, direction, file, sha256, license: String
        let name_en, name_ar, author_en, author_ar: String
        let bytes, version: Int
    }
    let schemaVersion: Int
    let packs: [Entry]

    static func load() throws -> ManifestFile {
        try JSONDecoder().decode(ManifestFile.self, from: Data(contentsOf: Paths.packReport("qul")))
    }
}

@Suite(.enabled(if: Paths.qulBuilt, "build the qul profile first")) struct TranslationPacks {
    struct Row { let ayahID: Int; let text: String; let footnotes: [String: String] }

    static func rows(_ file: String) throws -> [Row] {
        let db = try SQLiteDatabase(path: Paths.packs("qul").appendingPathComponent(file).path, readOnly: true)
        var rows: [Row] = []
        try db.query("SELECT ayah_id, text, footnotes_json FROM translation ORDER BY ayah_id") { row in
            let notes = row.text(2).map { (try? JSONDecoder().decode([String: String].self, from: Data($0.utf8))) ?? ["<invalid json>": ""] } ?? [:]
            rows.append(Row(ayahID: row.int(0)!, text: row.text(1)!, footnotes: notes))
        }
        return rows
    }

    @Test func manifestMatchesTheFiles() throws {
        let manifest = try ManifestFile.load()
        #expect(manifest.schemaVersion == 2)
        #expect(manifest.packs.map(\.id) == ["en-sahih-international", "ar-muyassar", "en-mukhtasar", "surah-info-en"])
        for pack in manifest.packs {
            let url = Paths.packs("qul").appendingPathComponent(pack.file)
            #expect(try SourceManifest.sha256(of: url) == pack.sha256, "\(pack.id)")
            #expect((try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) == pack.bytes, "\(pack.id)")
            #expect(["ltr", "rtl"].contains(pack.direction))
            let db = try SQLiteDatabase(path: url.path, readOnly: true)
            var header: [String] = []
            try db.query("SELECT id, kind, language, name, direction FROM pack") { row in header = (0..<5).map { row.text(Int32($0)) ?? "" } }
            #expect(header == [pack.id, pack.kind, pack.language, pack.name_en, pack.direction])
            // The pack describes its Arabic names itself (columns 9 and 10), so no manifest is needed to show them.
            var arabic: [String] = []
            try db.query("SELECT name_ar, author_ar FROM pack") { row in arabic = [row.text(0) ?? "", row.text(1) ?? ""] }
            #expect(arabic == [pack.name_ar, pack.author_ar], "\(pack.id)")
            // Both UI languages have a name and an author; the Arabic ones are in Arabic script.
            for text in [pack.name_ar, pack.author_ar] {
                #expect(text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }, "\(pack.id): \(text)")
            }
            #expect(!pack.name_en.isEmpty && !pack.author_en.isEmpty)
        }
        let files = Set(try FileManager.default.contentsOfDirectory(atPath: Paths.packs("qul").path).filter { !$0.hasPrefix(".") })
        #expect(files == Set(manifest.packs.map(\.file)))
    }

    @Test func saheehCoversEveryAyahWithResolvedFootnotes() throws {
        let rows = try Self.rows("translation-en-sahih-international.sqlite")
        #expect(rows.map(\.ayahID) == Array(1...6236))
        var notes = 0
        var empty: [String] = []
        for row in rows {
            let ids = TranslationMarkup.footnoteIDs(in: row.text)
            #expect(Set(ids) == Set(row.footnotes.keys), "ayah \(row.ayahID)")   // every token resolves, every note is used
            notes += row.footnotes.count
            #expect(!row.text.contains("<") && !row.text.contains(">"), "ayah \(row.ayahID): leftover tag")
            #expect(row.footnotes.values.allSatisfy { !$0.contains("<") && !$0.contains(">") }, "ayah \(row.ayahID): note")
            empty += row.footnotes.filter { $0.value.isEmpty }.map(\.key)
            let withoutTokens = row.text.replacing(/\[\[fn:[^\]]+\]\]/, with: "")
            #expect(!withoutTokens.contains("[[") && !withoutTokens.contains("]]"), "ayah \(row.ayahID)")
        }
        #expect(notes == 1904)
        // QUL's note 226798 (7:143, after "It crumbled to dust.") is an empty string. Kept as
        // given (README findings); the app shows no marker for an empty note.
        #expect(empty == ["226798"])
    }

    @Test func spotChecks() throws {
        let rows = try Self.rows("translation-en-sahih-international.sqlite")
        #expect(rows[0].text == "In the name of Allāh,[[fn:226402]] the Entirely Merciful, the Especially Merciful.[[fn:226403]]")
        #expect(rows[0].footnotes["226402"]?.hasPrefix("Allāh is a proper name") == true)
        // 2:255 (ayah id 262): six footnotes.
        #expect(TranslationMarkup.footnoteIDs(in: rows[261].text) == ["226497", "226498", "226499", "226500", "226501", "226502"])
        #expect(rows[261].text.hasPrefix("Allāh - there is no deity except Him, the Ever-Living,[[fn:226497]]"))
        // 4:12's note had <p>…</p><p>… mid-sentence: block tags become one space (reported finding).
        let note = try #require(rows.first { $0.footnotes["226564"] != nil }?.footnotes["226564"])
        #expect(note.contains("Those from the father or both parents"))
    }

    @Test func searchIndexFoldsDiacritics() throws {
        let db = try SQLiteDatabase(path: Paths.packs("qul").appendingPathComponent("translation-en-sahih-international.sqlite").path, readOnly: true)
        func hits(_ query: String) throws -> [Int] {
            var ids: [Int] = []
            try db.query("SELECT rowid FROM pack_fts WHERE pack_fts MATCH ? ORDER BY rowid", [.text(query)]) { ids.append($0.int(0)!) }
            return ids
        }
        #expect(try hits("allah").contains(1))            // "Allāh"
        #expect(try hits("especially merciful").first == 1)
        #expect(try hits("kursi") == [262])              // 2:255 "Kursī"
        #expect(try hits("226402").isEmpty)              // footnote tokens are not indexed
    }
}

@Suite struct TranslationMarkupConversion {
    @Test func footnoteTagsBecomeTokens() throws {
        let result = try TranslationMarkup.convertFootnoteTags(
            text: #"Praise<sup foot_note="7">1</sup> be <b>to</b> Him.<sup foot_note="8">2</sup>"#,
            footnotes: ["7": "<p>One</p><p>two</p>", "8": "A &amp; B"]
        )
        #expect(result.text == "Praise[[fn:7]] be to Him.[[fn:8]]")
        #expect(result.footnotes == ["7": "One two", "8": "A & B"])
    }

    @Test func brokenFootnotesFailTheBuild() {
        #expect(throws: TranslationMarkup.ConversionError.unresolvedFootnote(id: "9")) {
            try TranslationMarkup.convertFootnoteTags(text: #"x<sup foot_note="9">1</sup>"#, footnotes: [:])
        }
        #expect(throws: TranslationMarkup.ConversionError.unusedFootnote(id: "3")) {
            try TranslationMarkup.convertFootnoteTags(text: "x", footnotes: ["3": "note"])
        }
        #expect(throws: TranslationMarkup.ConversionError.reservedSequence("a [[b]]")) {
            try TranslationMarkup.convertFootnoteTags(text: "a [[b]]", footnotes: [:])
        }
    }

    @Test func searchTextDropsTokensAndItalics() {
        #expect(TranslationMarkup.searchText("He *said*,[[fn:1]] go.") == "He said, go.")
        #expect(TranslationMarkup.footnoteIDs(in: "a[[fn:1]] b[[fn:x2]]") == ["1", "x2"])
    }
}
