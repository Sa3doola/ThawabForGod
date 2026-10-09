// Phase 8.0: the curated "Ayah of the day" list and the JSON each built profile writes from it.
// One test per built profile: a profile not built is skipped with the reason, never passed with
// zero cases.

import Foundation
import QuranDataModel
import Testing

@Suite struct CuratedAyahOfTheDay {
    static let source = Paths.curatedList

    /// Every surah's ayah count, from a profile's database (`ayah` has the same schema in both).
    private func ayahCounts(database: URL) throws -> [Int] {
        let db = try SQLiteDatabase(path: database.path, readOnly: true)
        var counts: [Int] = []
        try db.query("SELECT surah, max(ayah) FROM ayah GROUP BY surah ORDER BY surah") { counts.append($0.int(1)!) }
        return counts
    }

    private func checkEntries(database: URL) throws {
        let entries = try CuratedAyahList.parse(String(contentsOf: Self.source, encoding: .utf8))
        let counts = try ayahCounts(database: database)
        #expect(counts.count == 114)
        #expect(CuratedAyahList.problems(entries, ayahCounts: counts, minimumCount: 60).isEmpty)
        #expect((100...140).contains(entries.count), "about 120 entries, \(entries.count)")
    }

    /// The bundled JSON is the pipeline's output for the current source (rebuild after editing).
    private func checkJSON(profile: String) throws {
        let text = try String(contentsOf: Self.source, encoding: .utf8)
        let output = try JSONDecoder().decode(CuratedAyahList.Output.self, from: Data(contentsOf: Paths.curatedJSON(profile)))
        #expect(output.entries == (try CuratedAyahList.parse(text)), "run BuildQuranData after editing the list")
        #expect(output.sha256 == (try SourceManifest.sha256(of: Self.source)))
        #expect(output.status.localizedCaseInsensitiveContains("reviewed by Saad"))
    }

    @Test(.enabled(if: Paths.qulBuilt, "build the qul profile first"))
    func qulEveryEntryExistsAndNoAyahIsListedTwice() throws {
        try checkEntries(database: Paths.quranSQLite)
    }

    @Test(.enabled(if: Paths.tanzilBuilt, "build the tanzil profile first"))
    func tanzilEveryEntryExistsAndNoAyahIsListedTwice() throws {
        try checkEntries(database: Paths.tanzilSQLite)
    }

    @Test(.enabled(if: Paths.qulBuilt, "build the qul profile first"))
    func qulBundledJSONMatchesTheSource() throws {
        try checkJSON(profile: "qul")
    }

    @Test(.enabled(if: Paths.tanzilBuilt, "build the tanzil profile first"))
    func tanzilBundledJSONMatchesTheSource() throws {
        try checkJSON(profile: "tanzil")
    }

    @Test func parserRejectsBadLines() throws {
        #expect(throws: CuratedAyahList.ParseError.self) { try CuratedAyahList.parse("2:255\n") }
        #expect(throws: CuratedAyahList.ParseError.self) { try CuratedAyahList.parse("2-255  # note\n") }
        let parsed = try CuratedAyahList.parse("# header\n\n94:5-6  # ease\n2:255 # kursi\n")
        #expect(parsed == [.init(surah: 94, from: 5, to: 6), .init(surah: 2, from: 255, to: 255)])
        let counts = [7, 286]
        #expect(CuratedAyahList.problems([.init(surah: 2, from: 287, to: 287)], ayahCounts: counts, minimumCount: 0).count == 1)
        #expect(CuratedAyahList.problems([.init(surah: 2, from: 5, to: 4)], ayahCounts: counts, minimumCount: 0).count == 1)
        #expect(CuratedAyahList.problems([.init(surah: 3, from: 1, to: 1)], ayahCounts: counts, minimumCount: 0).count == 1)
        #expect(CuratedAyahList.problems([.init(surah: 2, from: 1, to: 3), .init(surah: 2, from: 3, to: 3)], ayahCounts: counts, minimumCount: 0).count == 1)
        #expect(CuratedAyahList.problems([.init(surah: 1, from: 1, to: 7)], ayahCounts: counts, minimumCount: 60).count == 1)
    }
}
