// Phase 4.1: tafsir packs, read from the qul profile's pack folder (docs/03 pack schema, docs/05 HTML subset).

import Foundation
import QuranDataModel
import Testing

/// What the bundled tafsirs must look like, per pack.
struct TafsirExpectation: Sendable, CustomStringConvertible {
    let file: String
    let groups: Int
    /// Groups that are not contiguous or span surahs, by owner key. Reported as findings by the
    /// pipeline; none in either bundled pack.
    let groupExceptions: Set<String>

    var description: String { file }

    static let all = [
        TafsirExpectation(file: "tafsir-ar-muyassar.sqlite", groups: 5040, groupExceptions: []),
        TafsirExpectation(file: "tafsir-en-mukhtasar.sqlite", groups: 6216, groupExceptions: []),
    ]
}

@Suite(.enabled(if: Paths.qulBuilt, "build the qul profile first")) struct TafsirPacks {
    struct Row { let ayahID: Int; let group: Int; let html: String? }

    static func rows(_ file: String) throws -> [Row] {
        let db = try SQLiteDatabase(path: Paths.packs("qul").appendingPathComponent(file).path, readOnly: true)
        var rows: [Row] = []
        try db.query("SELECT ayah_id, group_ayah_id, html FROM tafsir ORDER BY ayah_id") { row in
            rows.append(Row(ayahID: row.int(0)!, group: row.int(1)!, html: row.text(2)))
        }
        return rows
    }

    /// Ayah id → (surah, ayah), from quran.sqlite.
    static func ayahKeys() throws -> [Int: (surah: Int, ayah: Int)] {
        let db = try SQLiteDatabase(path: Paths.quranSQLite.path, readOnly: true)
        var keys: [Int: (surah: Int, ayah: Int)] = [:]
        try db.query("SELECT id, surah, ayah FROM ayah") { keys[$0.int(0)!] = (surah: $0.int(1)!, ayah: $0.int(2)!) }
        return keys
    }

    /// The only tags sanitized HTML may contain, exactly as the pipeline writes them.
    static let allowedTags: Set<String> = Set(
        ["p", "br", "b", "i", "h1", "h2", "h3", "h4", "ul", "ol", "li", "sup"].flatMap { ["<\($0)>", "</\($0)>"] }
        + [#"<div lang="ar">"#, "</div>", #"<span lang="ar">"#, #"<span lang="ar" class="quran">"#, "</span>"]
    ).subtracting(["</br>"])

    @Test(arguments: TafsirExpectation.all)
    func everyAyahResolvesToText(_ expected: TafsirExpectation) throws {
        let rows = try Self.rows(expected.file)
        #expect(rows.map(\.ayahID) == Array(1...6236))
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.ayahID, $0) })
        var owners = 0
        for row in rows {
            let owner = try #require(byID[row.group], "ayah \(row.ayahID): group \(row.group) has no row")
            #expect(owner.group == owner.ayahID, "ayah \(row.ayahID): group \(row.group) is not an owner")
            if row.group == row.ayahID {
                owners += 1
                let html = try #require(row.html, "owner \(row.ayahID) has no html")
                #expect(!TafsirHTML.plainText(html).isEmpty, "owner \(row.ayahID): no text")
            } else {
                #expect(row.html == nil, "ayah \(row.ayahID) points to \(row.group) but has html")
            }
        }
        #expect(owners == expected.groups)
    }

    @Test(arguments: TafsirExpectation.all)
    func groupsAreContiguousWithinOneSurah(_ expected: TafsirExpectation) throws {
        let rows = try Self.rows(expected.file)
        let keys = try Self.ayahKeys()
        var exceptions: Set<String> = []
        for (owner, members) in Dictionary(grouping: rows, by: \.group) {
            let ids = members.map(\.ayahID).sorted()
            let contiguous = ids == Array(ids.first!...ids.last!)
            let oneSurah = Set(ids.map { keys[$0]!.surah }).count == 1
            if !contiguous || !oneSurah || ids.first != owner { exceptions.insert("\(keys[owner]!.surah):\(keys[owner]!.ayah)") }
        }
        #expect(exceptions == expected.groupExceptions)
    }

    @Test(arguments: TafsirExpectation.all)
    func noDisallowedTagsRemain(_ expected: TafsirExpectation) throws {
        var seen: Set<String> = []
        for row in try Self.rows(expected.file) {
            guard let html = row.html else { continue }
            let tags = TafsirHTML.tags(in: html)
            seen.formUnion(tags)
            #expect(Set(tags).isSubset(of: Self.allowedTags), "ayah \(row.ayahID): \(Set(tags).subtracting(Self.allowedTags))")
            // Only the three escapes the pipeline writes; no raw '<' or '>' outside tags.
            let text = html.replacing(/<[^>]*>/, with: "")
            #expect(!text.contains("<") && !text.contains(">"), "ayah \(row.ayahID)")
            #expect(text.matches(of: /&[#A-Za-z0-9]+;/).allSatisfy { ["&amp;", "&lt;", "&gt;"].contains(String($0.output)) }, "ayah \(row.ayahID)")
        }
        print("\(expected.file): tags \(seen.sorted())")
    }

    @Test func manifestListsBothTafsirs() throws {
        let tafsirs = try ManifestFile.load().packs.filter { $0.kind == "tafsir" }
        #expect(tafsirs.map(\.id) == ["ar-muyassar", "en-mukhtasar"])
        #expect(tafsirs.map(\.direction) == ["rtl", "ltr"])
        #expect(tafsirs.map(\.name_en) == ["Tafsir al-Muyassar", "Abridged Explanation of the Quran (Al-Mukhtasar)"])
        #expect(tafsirs.allSatisfy { $0.license.hasPrefix("unconfirmed") })
    }

    @Test func spotChecks() throws {
        let muyassar = try Self.rows("tafsir-ar-muyassar.sqlite")
        let mukhtasar = try Self.rows("tafsir-en-mukhtasar.sqlite")
        // 1:1 (Muyassar): surah intro headings, then the tafsir with three Quran quotes in Hafs.
        let fatihah = try #require(muyassar[0].html)
        #expect(fatihah.hasPrefix(#"<div lang="ar"><h3>تسمية السورة</h3>"#))
        #expect(fatihah.matches(of: /<h3>/).count == 3)
        #expect(fatihah.matches(of: /<span lang="ar" class="quran">/).count == 3)
        #expect(fatihah.contains(#"<span lang="ar" class="quran">﴿ٱلرَّحۡمَٰنِ﴾</span>"#))
        // 2:3–4 is one group in the English tafsir (ids 10, 11); separate in Muyassar.
        #expect(mukhtasar[9].group == 10 && mukhtasar[10].group == 10 && mukhtasar[10].html == nil)
        #expect(mukhtasar[9].html?.hasPrefix("They believe in the revelation") == true)
        #expect(muyassar[10].group == 11)
        // Muyassar's largest group: 81:1–14 (ids 5801…5814).
        #expect(muyassar[5800...5813].allSatisfy { $0.group == 5801 })
        #expect(muyassar[5814].group == 5815)
        // 3:3 (English) is one of ten entries wrapped in <p>; the rest are plain text.
        #expect(mukhtasar.compactMap(\.html).filter { $0.hasPrefix("<p>") }.count == 10)
    }

    @Test func searchIndexCoversEveryGroupOwner() throws {
        for file in ["tafsir-ar-muyassar.sqlite", "tafsir-en-mukhtasar.sqlite"] {
            let db = try SQLiteDatabase(path: Paths.packs("qul").appendingPathComponent(file).path, readOnly: true)
            func hits(_ query: String) throws -> [Int] {
                var ids: [Int] = []
                try db.query("SELECT rowid FROM pack_fts WHERE pack_fts MATCH ? ORDER BY rowid", [.text(query)]) { ids.append($0.int(0)!) }
                return ids
            }
            if file.contains("en") {
                #expect(try hits("rahman").contains(1))       // "Ar-Raḥmān", diacritics folded
                #expect(try hits("qpc").isEmpty)
            } else {
                #expect(try hits("الفاتحة").contains(1))
                #expect(try hits("quran").isEmpty)            // markup is not indexed
            }
        }
    }
}

@Suite struct TafsirHTMLSanitizer {
    @Test func keepsTheAllowedSubset() throws {
        let html = "<h3>Title</h3><p>One <b>two</b> <i>three</i><sup>1</sup><br/>four</p><ul><li>a</li></ul><ol><li>b</li></ol>"
        let result = try TafsirHTML.sanitize(html)
        #expect(result.html == "<h3>Title</h3><p>One <b>two</b> <i>three</i><sup>1</sup><br>four</p><ul><li>a</li></ul><ol><li>b</li></ol>")
        #expect(result.report.isEmpty)
    }

    @Test func renamesStrongAndEmAndDropsAttributes() throws {
        let result = try TafsirHTML.sanitize(#"<P class="x">a <STRONG>b</STRONG> <em style='c'>c</em></P>"#)
        #expect(result.html == "<p>a <b>b</b> <i>c</i></p>")
        #expect(result.report.mapped == ["strong → b": 1, "em → i": 1])
        #expect(result.report.droppedAttributes == ["p class=x": 1, "i style=c": 1])
    }

    @Test func keepsArabicMarkersAndMapsQuranQuotes() throws {
        let result = try TafsirHTML.sanitize(#"<div class=ar lang=ar><p>قال <span class="qpc-hafs">﴿ٱللَّهِ﴾</span></p></div>"#)
        #expect(result.html == #"<div lang="ar"><p>قال <span lang="ar" class="quran">﴿ٱللَّهِ﴾</span></p></div>"#)
        #expect(result.report.droppedAttributes == ["div class=ar": 1])
        #expect(result.report.mapped == [#"span class=qpc-hafs → span lang=ar class=quran"#: 1])
        let inline = try TafsirHTML.sanitize(#"He said <span lang="AR">بسم الله</span>."#)
        #expect(inline.html == #"He said <span lang="ar">بسم الله</span>."#)
    }

    @Test func unwrapsWrappersAndReportsThem() throws {
        let result = try TafsirHTML.sanitize(#"<p>See <a href="https://x">this</a> and <font color=red>that</font> <span class="y">too</span><!-- note --></p>"#)
        #expect(result.html == "<p>See this and that too</p>")
        #expect(result.report.droppedTags == ["<a>": 1, "<font>": 1, "<span> without lang=ar (class=y)": 1, "<!-- comment -->": 1])
        #expect(result.report.droppedAttributes == ["href=https://x": 1, "color=red": 1])
    }

    @Test func decodesAndEscapesEntities() throws {
        let result = try TafsirHTML.sanitize("<p>A &amp; B &lt;C&gt; &#1575; &#x627; &nbsp;x & y</p>")
        #expect(result.html == "<p>A &amp; B &lt;C&gt; ا ا \u{00A0}x &amp; y</p>")
        #expect(TafsirHTML.plainText(result.html) == "A & B <C> ا ا x & y")   // the no-break space collapses too
    }

    @Test func failsOnWhatItCannotMap() {
        #expect(throws: TafsirHTML.SanitizeError.unknownTag("script")) { try TafsirHTML.sanitize("<p>a<script>x()</script></p>") }
        #expect(throws: TafsirHTML.SanitizeError.unknownTag("table")) { try TafsirHTML.sanitize("<table><tr><td>a</td></tr></table>") }
        #expect(throws: TafsirHTML.SanitizeError.unknownTag("img")) { try TafsirHTML.sanitize(#"<img src="x.png">"#) }
        #expect(throws: TafsirHTML.SanitizeError.unbalanced("</b> closes <p>")) { try TafsirHTML.sanitize("<p>a</b>") }
        #expect(throws: TafsirHTML.SanitizeError.unbalanced("<p> is never closed")) { try TafsirHTML.sanitize("<p>a") }
        #expect(throws: TafsirHTML.SanitizeError.unknownEntity("&hellip;")) { try TafsirHTML.sanitize("a&hellip;") }
        #expect(throws: TafsirHTML.SanitizeError.strayBracket("a > b")) { try TafsirHTML.sanitize("a > b") }
        #expect(throws: TafsirHTML.SanitizeError.empty) { try TafsirHTML.sanitize("<p> </p>") }
        #expect(throws: (any Error).self) { try TafsirHTML.sanitize("1 < 2") }
    }

    @Test func plainTextSeparatesBlocks() {
        #expect(TafsirHTML.plainText("<h3>T</h3><p>a <b>b</b></p><p>c</p>") == "T a b c")
    }
}
