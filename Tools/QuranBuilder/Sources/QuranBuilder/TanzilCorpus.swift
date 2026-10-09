import CryptoKit
import Foundation
import QuranDataModel

/// The `tanzil` profile: Tanzil's Uthmani text, its Simple Clean text for search, and
/// `quran-data.xml` for the surahs and the reciter's divisions. No page layout and no glyphs —
/// the public build, which separated mode reads.
///
/// Ported from `Tools/CorpusBuilder/build_quran_db.py`, with its sources, pins and checks. Every
/// check below is a silently wrong Quran rather than an error if it is skipped, so each one stops
/// the build.
struct TanzilCorpus {
    struct Verse {
        let surah: Int
        let number: Int
        let text: String
    }

    struct Surah {
        let index: Int
        let name: String
        let transliteration: String
        let ayahs: Int
        /// "meccan" or "medinan", as Tanzil spells it (lowercased).
        let type: String
        let order: Int
    }

    struct Download {
        let raw: String
        let sha256: String
        let path: String
    }

    let text: Download
    let searchText: Download
    let metadata: Download

    /// Al-Fatiha opens *with* the basmala as its first verse — numbered, part of the chapter — and
    /// At-Tawba is the one chapter that does not begin with it at all. The other 112 carry it as
    /// a prefix of verse 1 in Tanzil's text, and the mushaf prints it above the chapter instead.
    static let noBasmalaHeading: Set<Int> = [1, 9]

    static let juzCount = 30
    /// Tanzil publishes the divisions as 240 *quarters* — the rub el hizb — and the coarser two
    /// fall out of them: four quarters to a hizb, eight to a juz.
    static let quarterCount = 240
    static let quartersPerHizb = 4
    static let manzilCount = 7
    static let rukuCount = 556
    static let sajdahCount = 15

    /// Tanzil's two kinds of prostration in the schema's vocabulary, which is QUL's. The fifteen
    /// verses and which four are obligatory agree between the two sources.
    static let sajdahTypes = ["obligatory": "required", "recommended": "optional"]

    // MARK: Loading

    static func load(_ config: BuildConfig) async throws -> TanzilCorpus {
        let tanzil = config.tanzil!
        return TanzilCorpus(
            text: try await download(tanzil.text.url, cache: config.path(tanzil.text.cache)),
            searchText: try await download(tanzil.searchText.url, cache: config.path(tanzil.searchText.cache)),
            metadata: try await download(tanzil.metadata.url, cache: config.path(tanzil.metadata.cache))
        )
    }

    /// The cached copy if there is one, else a fresh download written to the cache. The text pins
    /// are over the verses, so a cache from last year and a download from today both verify.
    private static func download(_ url: String, cache: URL) async throws -> Download {
        let data: Data
        if FileManager.default.fileExists(atPath: cache.path) {
            data = try Data(contentsOf: cache)
        } else {
            guard let remote = URL(string: url) else { throw BuildError.data("bad URL \(url)") }
            let (body, response) = try await URLSession.shared.data(from: remote)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            try require(status == 200, "\(url): HTTP \(status)")
            try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
            try body.write(to: cache, options: .atomic)
            print("downloaded \(url) → \(cache.path)")
            data = body
        }
        guard let raw = String(data: data, encoding: .utf8) else { throw BuildError.data("\(cache.lastPathComponent): not UTF-8") }
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return Download(raw: raw, sha256: sha, path: cache.lastPathComponent)
    }

    // MARK: Parsing

    /// `sura|aya|text` lines, with the copyright block and blank lines dropped.
    static func parseVerses(_ raw: String) throws -> [Verse] {
        var verses: [Verse] = []
        for line in raw.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3, let surah = Int(parts[0]), let number = Int(parts[1]) else {
                throw BuildError.data("not a sura|aya|text line: \(line.prefix(40))")
            }
            let text = parts[2].trimmingCharacters(in: .whitespaces)
            try require(!text.isEmpty, "verse \(surah):\(number) is empty upstream")
            verses.append(Verse(surah: surah, number: number, text: text))
        }
        return verses
    }

    /// Tanzil's copyright block, verbatim, with the leading `#` markers stripped. Kept because
    /// their terms ask for it to be reproduced in derived files, and the database is one.
    static func parseNotice(_ raw: String) throws -> String {
        let lines = raw.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("#") }
            .map { $0.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.allSatisfy { $0 == "=" } }
        let notice = lines.joined(separator: "\n")
        try require(notice.contains("Tanzil Project"),
                    "the download carries no Tanzil copyright block; their terms require it in derived files")
        return notice
    }

    /// SHA-256 of the verses joined as `sura|aya|text` lines — the pin, independent of the
    /// copyright block's year.
    static func digest(_ verses: [Verse]) -> String {
        let joined = verses.map { "\($0.surah)|\($0.number)|\($0.text)" }.joined(separator: "\n")
        return SHA256.hash(data: Data(joined.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func document(_ raw: String) throws -> XMLDocument {
        try XMLDocument(data: Data(raw.utf8))
    }

    static func parseSurahs(_ metadata: String) throws -> [Surah] {
        let surahs = try document(metadata).nodes(forXPath: "/quran/suras/sura").compactMap { $0 as? XMLElement }.map { element in
            func attribute(_ name: String) throws -> String {
                guard let value = element.attribute(forName: name)?.stringValue else {
                    throw BuildError.data("a <sura> has no \(name)")
                }
                return value
            }
            guard let index = Int(try attribute("index")), let ayahs = Int(try attribute("ayas")),
                  let order = Int(try attribute("order")) else { throw BuildError.data("a <sura> has a non-numeric field") }
            return Surah(
                index: index, name: try attribute("name"), transliteration: try attribute("tname"),
                ayahs: ayahs, type: try attribute("type").lowercased(), order: order
            )
        }.sorted { $0.index < $1.index }
        try require(surahs.map(\.index) == Array(1...114), "quran-data.xml: suras are not 1…114")
        return surahs
    }

    /// The `(surah, verse)` each section begins on, in order. Every division is published the
    /// same way — as the single verse it starts at — and the caller says how many there must be.
    static func parseStarts(_ metadata: String, container: String, tag: String, expected: Int) throws -> [AyahKey] {
        let starts = try document(metadata).nodes(forXPath: "/quran/\(container)/\(tag)").compactMap { $0 as? XMLElement }.map { element in
            guard let surah = element.attribute(forName: "sura")?.stringValue.flatMap(Int.init),
                  let ayah = element.attribute(forName: "aya")?.stringValue.flatMap(Int.init) else {
                throw BuildError.data("a <\(tag)> has no sura/aya")
            }
            return AyahKey(surah: surah, ayah: ayah)
        }
        try require(starts.count == expected, "expected \(expected) <\(tag)> entries, quran-data.xml has \(starts.count)")
        try require(starts == starts.sorted(), "<\(tag)> entries are not in canonical order")
        return starts
    }

    static func parseSajdahs(_ metadata: String) throws -> [AyahKey: String] {
        var sajdahs: [AyahKey: String] = [:]
        for element in try document(metadata).nodes(forXPath: "/quran/sajdas/sajda").compactMap({ $0 as? XMLElement }) {
            guard let surah = element.attribute(forName: "sura")?.stringValue.flatMap(Int.init),
                  let ayah = element.attribute(forName: "aya")?.stringValue.flatMap(Int.init),
                  let type = element.attribute(forName: "type")?.stringValue else {
                throw BuildError.data("a <sajda> is incomplete")
            }
            guard let mapped = sajdahTypes[type] else { throw BuildError.data("unknown sajda type '\(type)'") }
            sajdahs[AyahKey(surah: surah, ayah: ayah)] = mapped
        }
        try require(sajdahs.count == sajdahCount, "expected \(sajdahCount) sajdas, quran-data.xml has \(sajdahs.count)")
        return sajdahs
    }

    /// Numbers every verse by the section it falls in: the last one that began at or before it.
    static func assign(_ verses: [Verse], starts: [AyahKey], what: String) throws -> [Int] {
        let boundaries = Dictionary(uniqueKeysWithValues: starts.enumerated().map { ($0.element, $0.offset + 1) })
        var current = 0
        var assigned: [Int] = []
        for verse in verses {
            current = boundaries[AyahKey(surah: verse.surah, ayah: verse.number)] ?? current
            try require(current != 0, "verse \(verse.surah):\(verse.number) falls before the first \(what)")
            assigned.append(current)
        }
        try require(current == starts.count, "the last \(what) (\(starts.count)) has no verses in it")
        return assigned
    }

    /// The letters alone, every combining mark dropped. Used only to *recognise* the basmala,
    /// never to store it: two chapters (Al-Tin, Al-Qadr) carry an extra shadda on the opening ba.
    static func skeleton(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { $0.properties.canonicalCombiningClass == .notReordered }))
    }

    /// Lifts the basmala off verse 1 of the 112 chapters that carry it as a prefix. The mushaf
    /// prints it above the chapter, unnumbered; the prefix is recognised by its letters and the
    /// rest of the verse is kept exactly as it arrived.
    static func splitBasmala(_ verses: [Verse]) throws -> [Verse] {
        guard let canonical = verses.first(where: { $0.surah == 1 && $0.number == 1 })?.text else {
            throw BuildError.data("no 1:1")
        }
        let key = skeleton(canonical)
        let wordCount = canonical.split(whereSeparator: \.isWhitespace).count
        var headings = 0
        let split = try verses.map { verse -> Verse in
            guard verse.number == 1, !noBasmalaHeading.contains(verse.surah) else { return verse }
            let words = verse.text.split(whereSeparator: \.isWhitespace)
            let prefix = words.prefix(wordCount).joined(separator: " ")
            let remainder = words.dropFirst(wordCount).joined(separator: " ")
            try require(skeleton(prefix) == key, "surah \(verse.surah): verse 1 does not open with the basmala")
            try require(!remainder.isEmpty, "surah \(verse.surah): verse 1 is the basmala and nothing else")
            headings += 1
            return Verse(surah: verse.surah, number: 1, text: remainder)
        }
        try require(headings == 114 - noBasmalaHeading.count, "expected 112 basmala headings, found \(headings)")
        return split
    }

    // MARK: Rows

    func rows(textDigest: String, searchDigest: String) throws -> QuranCorpusRows {
        let verses = try Self.parseVerses(text.raw)
        let searchVerses = try Self.parseVerses(searchText.raw)
        let surahs = try Self.parseSurahs(metadata.raw)

        // Checked against the files exactly as downloaded, before the basmala is moved, so the
        // pinned digests track upstream rather than this code.
        try require(verses.count == 6236, "expected 6,236 verses, the text has \(verses.count)")
        let actualText = Self.digest(verses)
        try require(actualText == textDigest, """
            the Tanzil Uthmani text has changed upstream.
              expected \(textDigest)
              got      \(actualText)
            Read tanzil.net/updates before re-pinning: this is the text of the Quran.
            """)
        try require(searchVerses.map { AyahKey(surah: $0.surah, ayah: $0.number) } == verses.map { AyahKey(surah: $0.surah, ayah: $0.number) },
                    "the Uthmani and Simple Clean texts do not cover the same verses in the same order")
        let actualSearch = Self.digest(searchVerses)
        try require(actualSearch == searchDigest, """
            Tanzil's Simple Clean text has changed upstream.
              expected \(searchDigest)
              got      \(actualSearch)
            Nothing a reader sees comes from this text, but what they can find does.
            """)
        for surah in surahs {
            let numbers = verses.filter { $0.surah == surah.index }.map(\.number)
            try require(numbers == Array(1...surah.ayahs), "surah \(surah.index): verse numbers are not 1…\(surah.ayahs)")
        }

        // Divided before the basmala is lifted: the boundaries are stated against Tanzil's
        // numbering. Hizb is derived from the quarter rather than parsed, so the three cannot
        // disagree by a verse.
        let juzStarts = try Self.parseStarts(metadata.raw, container: "juzs", tag: "juz", expected: Self.juzCount)
        let quarterStarts = try Self.parseStarts(metadata.raw, container: "hizbs", tag: "quarter", expected: Self.quarterCount)
        try require(stride(from: 0, to: quarterStarts.count, by: Self.quartersPerHizb * 2).map { quarterStarts[$0] } == juzStarts,
                    "every eighth quarter should be where a juz begins, and quran-data.xml no longer says so")
        let juz = try Self.assign(verses, starts: juzStarts, what: "juz")
        let quarters = try Self.assign(verses, starts: quarterStarts, what: "quarter")
        let manzils = try Self.assign(verses, starts: Self.parseStarts(metadata.raw, container: "manzils", tag: "manzil", expected: Self.manzilCount), what: "manzil")
        let rukus = try Self.assign(verses, starts: Self.parseStarts(metadata.raw, container: "rukus", tag: "ruku", expected: Self.rukuCount), what: "ruku")
        let sajdahs = try Self.parseSajdahs(metadata.raw)

        let staticJuz = verses.map { StaticTables.juz(surah: $0.surah, ayah: $0.number) }
        try require(juz == staticJuz, "Tanzil's juz boundaries differ from StaticTables.juzStarts")

        // The same cut on both texts, so a verse's displayed and searched forms stay one verse.
        let displayed = try Self.splitBasmala(verses)
        let searched = try Self.splitBasmala(searchVerses)

        var findings: [String] = []
        let surahRows = surahs.map { surah in
            let table = StaticTables.surahNames[surah.index - 1]
            if surah.name != table.ar { findings.append("surah \(surah.index): Tanzil spells '\(surah.name)', the printed header '\(table.ar)' is kept") }
            let revelation = surah.type == "medinan" ? "madinah" : "makkah"
            if (revelation == "madinah") != StaticTables.madinanSurahs.contains(surah.index) {
                findings.append("surah \(surah.index): Tanzil says \(surah.type), the static table (QUL) says otherwise; Tanzil's is kept")
            }
            return SurahRow(
                id: surah.index, nameAr: table.ar, nameEn: table.en, nameTranslit: surah.transliteration,
                ayahCount: surah.ayahs, revelation: revelation, revelationOrder: surah.order,
                bismillahPre: !Self.noBasmalaHeading.contains(surah.index)
            )
        }
        for finding in findings { print("finding: \(finding)") }

        let ayahRows = displayed.indices.map { index in
            let verse = displayed[index]
            return AyahRow(
                id: index + 1, surah: verse.surah, ayah: verse.number,
                juz: juz[index], hizb: (quarters[index] - 1) / Self.quartersPerHizb + 1, rub: quarters[index],
                manzil: manzils[index], ruku: rukus[index],
                sajdah: sajdahs[AyahKey(surah: verse.surah, ayah: verse.number)],
                textHafs: verse.text, textImlaei: searched[index].text
            )
        }

        let notices = [
            ("tanzil-uthmani", "Tanzil Project — Uthmani text", try Self.parseNotice(text.raw)),
            ("tanzil-simple-clean", "Tanzil Project — Simple Clean text", try Self.parseNotice(searchText.raw)),
        ]
        var meta: [(String, String)] = [
            ("text_source", "tanzil-uthmani"),
            ("search_source", "tanzil-simple-clean"),
            ("digest:tanzil-uthmani", actualText),
            ("digest:tanzil-simple-clean", actualSearch),
        ]
        for download in [text, searchText, metadata] { meta.append(("sha256:tanzil/\(download.path)", download.sha256)) }
        for (id, name, notice) in notices {
            meta += [
                ("source:\(id):name", name),
                ("source:\(id):url", "https://tanzil.net"),
                ("source:\(id):licence", "Creative Commons Attribution 3.0"),
                ("source:\(id):notice", notice),
            ]
        }

        return QuranCorpusRows(surahs: surahRows, ayahs: ayahRows, capabilities: [.text], meta: meta)
    }
}
