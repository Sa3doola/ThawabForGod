// Phase 5.4: the surah information pack (docs/07), sanitized with the tafsir HTML subset.

import Foundation
import QuranDataModel
import Testing

@Suite struct SurahInfoPacks {
    @Test(.enabled(if: Paths.qulBuilt, "build the qul profile first"))
    func englishSurahInfoCoversEverySurah() throws {
        let entry = try #require(try ManifestFile.load().packs.first { $0.kind == "surah-info" })
        #expect(entry.id == "surah-info-en")
        #expect(entry.language == "en" && entry.direction == "ltr")
        #expect(entry.license.hasPrefix("unconfirmed"))

        let db = try SQLiteDatabase(path: Paths.packs("qul").appendingPathComponent(entry.file).path, readOnly: true)
        var surahs: [Int] = []
        var empty: [Int] = []
        var disallowed: [Int: Set<String>] = [:]
        try db.query("SELECT surah, name, summary, html FROM surah_info ORDER BY surah") { row in
            let surah = row.int(0)!
            surahs.append(surah)
            let html = row.text(3) ?? ""
            if (row.text(1) ?? "").isEmpty || (row.text(2) ?? "").isEmpty || TafsirHTML.plainText(html).isEmpty { empty.append(surah) }
            let tags = Set(html.matches(of: /<\/?([a-z0-9]+)/).map { String($0.output.1) })
            let extra = tags.subtracting(TafsirHTML.allowedTags)
            if !extra.isEmpty { disallowed[surah] = extra }
        }
        #expect(surahs == Array(1...114))
        #expect(empty.isEmpty, "surahs without text: \(empty)")
        #expect(disallowed.isEmpty, "\(disallowed)")

        var fts = 0
        try db.query("SELECT count(*) FROM pack_fts WHERE pack_fts MATCH 'Fatihah'") { fts = $0.int(0)! }
        #expect(fts > 0)
    }

    // Pure function on a literal string: needs no built output, so it runs unconditionally.
    @Test func sanitizerUnwrapsStrikethrough() throws {
        let result = try TafsirHTML.sanitize("<p>honor<s>.</s></p>")
        #expect(result.html == "<p>honor.</p>")
        #expect(result.report.droppedTags["<s>"] == 1)
    }
}
