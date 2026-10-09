import ArabicText
import Foundation
import QuranDataModel

/// The `qul` profile: QUL's word-by-word Hafs and V2 glyph scripts, the KFGQPC V2 page layout, the
/// range tables, the ligature tables. Validated together, then handed to the writer as rows.
///
/// Ported from Mushaf's `QuranSQLiteBuilder` with its checks unchanged; only the writing moved to
/// `QuranSQLiteWriter`, which the `tanzil` profile shares.
struct QULCorpus {
    let words: [Word]
    let surahs: [SurahRecord]
    let metadata: QuranMetadataInput
    let styles: [StyleLayout]
    let ligatures: [LigatureTable]
    let inputHashes: [String: String]

    /// Range kinds stored per ayah, in schema order.
    static let rangeKinds = ["juz", "hizb", "rub", "manzil", "ruku"]
    /// Range kinds whose starts are marked in the page margins.
    static let markerKinds = ["juz", "hizb", "rub"]

    static func load(_ config: BuildConfig) throws -> QULCorpus {
        let qul = config.qul!
        let manifest = try SourceManifest(contentsOf: config.path(qul.sources))
        let hashes = try verifyInputs(config.qulInputs, manifest: manifest)
        print("verified \(hashes.count) QUL inputs against SOURCES.md")

        return QULCorpus(
            words: try loadWords(hafs: config.input(qul.words.hafs).url, glyphV2: config.input(qul.words.glyphV2).url),
            surahs: try loadSurahs(path: config.input(qul.surahs).url),
            metadata: try QuranMetadataInput.load(config),
            styles: try qul.styles.map { StyleLayout(id: $0.id, rows: try loadLayout(path: config.input($0.layout).url)) },
            ligatures: try loadLigatures(config),
            inputHashes: hashes
        )
    }

    // MARK: Validation

    /// Ayahs in canonical order, checked against the words and the surah metadata.
    func ayahs() throws -> [AyahRecord] {
        var ayahs: [AyahRecord] = []
        var index = 0
        while index < words.count {
            let first = words[index]
            var end = index
            while end < words.count, (words[end].surah, words[end].ayah) == (first.surah, first.ayah) { end += 1 }
            let ayahWords = words[index..<end]
            let key = "\(first.surah):\(first.ayah)"
            try require(ayahWords.map(\.position) == Array(1...ayahWords.count), "\(key): word positions are not contiguous")
            try require(ayahWords.filter(\.isMarker).count == 1 && ayahWords.last!.isMarker, "\(key): needs exactly one end marker, last")
            ayahs.append(AyahRecord(
                id: ayahs.count + 1,
                surah: first.surah,
                ayah: first.ayah,
                textHafs: ayahWords.dropLast().map(\.hafs).joined(separator: " ")
            ))
            index = end
        }
        // Canonical order: 1:1, 1:2, …, 114:6, each surah complete.
        let counts = Dictionary(grouping: ayahs, by: \.surah).mapValues(\.count)
        for surah in surahs {
            try require(counts[surah.id] == surah.versesCount, "surah \(surah.id): \(counts[surah.id] ?? 0) ayahs, metadata says \(surah.versesCount)")
        }
        try require(ayahs.map { "\($0.surah):\($0.ayah)" } == surahs.flatMap { s in (1...s.versesCount).map { "\(s.id):\($0)" } },
                    "ayahs are not in canonical order")
        return ayahs
    }

    /// Cross-checks the surah metadata against the static tables.
    func checkSurahNames() throws {
        for surah in surahs {
            let table = StaticTables.surahNames[surah.id - 1]
            try require(surah.nameSimple == table.en, "surah \(surah.id): QUL name '\(surah.nameSimple)', table '\(table.en)'")
        }
        let madinan = Set(surahs.filter { $0.revelationPlace == "madinah" }.map(\.id))
        try require(madinan == StaticTables.madinanSurahs, "Madinan surahs differ from the static table")
    }

    /// Unit number of each range kind for every ayah (index = ayah id − 1). Each table must
    /// cover every ayah exactly once, in order, and agree with its first/last verse keys.
    func assignRanges(_ ayahs: [AyahRecord]) throws -> [String: [Int]] {
        let index = Dictionary(uniqueKeysWithValues: ayahs.map { (AyahKey(surah: $0.surah, ayah: $0.ayah), $0.id - 1) })
        var result: [String: [Int]] = [:]
        for kind in Self.rangeKinds {
            let units = metadata.ranges[kind] ?? []
            var assigned = [Int?](repeating: nil, count: ayahs.count)
            for unit in units {
                let keys = unit.mapping.flatMap { surah, range in range.map { AyahKey(surah: surah, ayah: $0) } }
                try require(keys.min() == unit.first && keys.max() == unit.last,
                            "\(kind) \(unit.number): verse_mapping spans \(keys.min()!)–\(keys.max()!), keys say \(unit.first)–\(unit.last)")
                for key in keys {
                    guard let position = index[key] else { throw BuildError.data("\(kind) \(unit.number): unknown ayah \(key)") }
                    try require(assigned[position] == nil, "\(kind): ayah \(key) is in \(assigned[position]!) and \(unit.number)")
                    assigned[position] = unit.number
                }
            }
            let numbers = assigned.compactMap { $0 }
            try require(numbers.count == ayahs.count, "\(kind): \(ayahs.count - numbers.count) ayahs not covered")
            try require(numbers == numbers.sorted(), "\(kind): units are not in Quran order")
            result[kind] = numbers
        }
        // The QUL juz table must agree with StaticTables.juzStarts.
        let staticJuz = ayahs.map { StaticTables.juz(surah: $0.surah, ayah: $0.ayah) }
        try require(result["juz"] == staticJuz, "QUL juz assignment differs from StaticTables.juzStarts")
        return result
    }

    /// Ayah-level QUL files share our global ids and keys. Word counts that differ from the
    /// script are returned as findings (reported, not fixed).
    @discardableResult
    func checkAyahEntries(_ ayahs: [AyahRecord]) throws -> [String] {
        var findings: [String] = []
        let wordCounts = Dictionary(grouping: words.filter { !$0.isMarker }, by: { AyahKey(surah: $0.surah, ayah: $0.ayah) })
            .mapValues(\.count)
        for (name, entries) in [("ayah metadata", metadata.ayahMetadata), ("Imlaei", metadata.imlaei)] {
            try require(entries.count == ayahs.count, "\(name): \(entries.count) entries")
            for (entry, ayah) in zip(entries, ayahs) {
                try require(entry.id == ayah.id && entry.key == AyahKey(surah: ayah.surah, ayah: ayah.ayah),
                            "\(name): id \(entry.id) is \(entry.key), expected \(ayah.surah):\(ayah.ayah)")
                try require(!entry.text.isEmpty, "\(name) \(entry.key): empty text")
                if let count = entry.wordsCount, count != wordCounts[entry.key] {
                    findings.append("\(name) \(entry.key): words_count \(count), the word-by-word script has \(wordCounts[entry.key] ?? 0)")
                }
            }
        }
        let sajdahKeys = Set(metadata.sajdahs.map(\.ayah))
        try require(sajdahKeys.count == metadata.sajdahs.count, "duplicate sajdah ayah")
        let known = Set(ayahs.map { AyahKey(surah: $0.surah, ayah: $0.ayah) })
        try require(sajdahKeys.isSubset(of: known), "sajdah on an unknown ayah")
        return findings
    }

    /// Every word (markers included) is on exactly one line of the style.
    func checkCoverage(_ style: StyleLayout) throws {
        var covered = [Int](repeating: 0, count: words.count + 1)
        for row in style.rows {
            switch row.kind {
            case "ayah":
                guard let first = row.firstWord, let last = row.lastWord, first <= last, last <= words.count else {
                    throw BuildError.data("\(style.id) page \(row.page) line \(row.line): bad word range")
                }
                for id in first...last { covered[id] += 1 }
            case "surah_name":
                try require(row.surah != nil && row.firstWord == nil, "\(style.id) page \(row.page) line \(row.line): header without surah")
            case "basmallah":
                try require(row.firstWord == nil, "\(style.id) page \(row.page) line \(row.line): basmala with words")
            default:
                throw BuildError.data("\(style.id): unknown line type '\(row.kind)'")
            }
        }
        let wrong = covered.indices.dropFirst().filter { covered[$0] != 1 }
        try require(wrong.isEmpty, "\(style.id): \(wrong.count) words not on exactly one line, e.g. \(wrong.prefix(5))")
    }

    // MARK: Rows

    func rows() throws -> QuranCorpusRows {
        try checkSurahNames()
        let ayahs = try ayahs()
        for finding in try checkAyahEntries(ayahs) { print("finding: \(finding)") }
        let ranges = try assignRanges(ayahs)
        for style in styles { try checkCoverage(style) }
        try checkSurahLigatures(ligatures)
        for table in ligatures where table.trimmedCount > 0 {
            print("finding: \(table.font) ligatures: \(table.trimmedCount) of \(table.entries.count) values had trailing whitespace (trimmed)")
        }
        let ayahID = Dictionary(uniqueKeysWithValues: ayahs.map { ("\($0.surah):\($0.ayah)", $0.id) })
        let sajdahByAyah = Dictionary(uniqueKeysWithValues: metadata.sajdahs.map { ($0.ayah, $0) })
        // First word and end marker of each ayah (index = ayah id − 1).
        var firstWord = [Int](repeating: 0, count: ayahs.count)
        var markerWord = [Int](repeating: 0, count: ayahs.count)
        for word in words {
            let id = ayahID["\(word.surah):\(word.ayah)"]! - 1
            if word.position == 1 { firstWord[id] = word.id }
            if word.isMarker { markerWord[id] = word.id }
        }

        var rows = QuranCorpusRows(
            surahs: surahs.map { surah in
                SurahRow(
                    id: surah.id,
                    // The static table keeps the hamza spellings of the printed headers; QUL
                    // spells six names differently (README findings). Reported, not merged.
                    nameAr: StaticTables.surahNames[surah.id - 1].ar,
                    nameEn: surah.nameSimple,
                    nameTranslit: surah.name,
                    ayahCount: surah.versesCount,
                    revelation: surah.revelationPlace,
                    revelationOrder: surah.revelationOrder,
                    bismillahPre: surah.bismillahPre
                )
            },
            ayahs: zip(ayahs, metadata.imlaei).map { ayah, imlaei in
                let index = ayah.id - 1
                return AyahRow(
                    id: ayah.id, surah: ayah.surah, ayah: ayah.ayah,
                    juz: ranges["juz"]![index], hizb: ranges["hizb"]![index], rub: ranges["rub"]![index],
                    manzil: ranges["manzil"]![index], ruku: ranges["ruku"]![index],
                    sajdah: sajdahByAyah[AyahKey(surah: ayah.surah, ayah: ayah.ayah)]?.type,
                    textHafs: ayah.textHafs, textImlaei: imlaei.text
                )
            },
            words: words.map { word in
                WordRow(
                    id: word.id, ayahID: ayahID["\(word.surah):\(word.ayah)"]!, position: word.position,
                    isMarker: word.isMarker, textHafs: word.hafs, glyphV2: word.glyphV2
                )
            },
            ligatures: ligatures,
            capabilities: [.text, .words, .mushafPages, .glyphV2, .fontLigatures],
            meta: [("styles", styles.map(\.id).joined(separator: ","))]
                + inputHashes.sorted { $0.key < $1.key }.map { ("sha256:\($0.key)", $0.value) }
        )

        for style in styles {
            rows.lines += style.rows.map { row in
                LineRow(
                    style: style.id, page: row.page, line: row.line, kind: row.kind, isCentered: row.isCentered,
                    firstWord: row.firstWord, lastWord: row.lastWord, surah: row.surah
                )
            }
            let pages = Dictionary(grouping: style.rows, by: \.page)
            for page in pages.keys.sorted() {
                // Ayahs with at least one word on the page (a wrapped end marker alone
                // does not count).
                let withWords = pages[page]!.flatMap { row -> [LineSegment<Word>] in
                    guard let first = row.firstWord, let last = row.lastWord else { return [] }
                    return LineSegmentation.segments(words[(first - 1)...(last - 1)]) { ($0.surah, $0.ayah, $0.isMarker) }
                }.filter { !$0.words.isEmpty }
                guard let firstAyah = withWords.first, let lastAyah = withWords.last else {
                    throw BuildError.data("\(style.id) page \(page) has no words")
                }
                // Labelled with the juz, hizb and rub of its last ayah: the ones that
                // begin on the page, when one does.
                let last = ayahID["\(lastAyah.surah):\(lastAyah.ayah)"]!
                rows.pages.append(PageRow(
                    style: style.id, page: page,
                    firstAyah: ayahID["\(firstAyah.surah):\(firstAyah.ayah)"]!, lastAyah: last,
                    juz: ranges["juz"]![last - 1], hizb: ranges["hizb"]![last - 1], rub: ranges["rub"]![last - 1]
                ))
            }

            // Margin markers. Juz/hizb/rub starts sit on the page of the ayah's first word
            // (where ۞ is printed); a sajdah on the page of the ayah's end (where ۩ is).
            var wordPage = [Int](repeating: 0, count: words.count + 1)
            for row in style.rows {
                guard let first = row.firstWord, let last = row.lastWord else { continue }
                for id in first...last { wordPage[id] = row.page }
            }
            for kind in Self.markerKinds {
                let numbers = ranges[kind]!
                for index in numbers.indices where index == 0 || numbers[index] != numbers[index - 1] {
                    rows.markers.append(MarkerRow(
                        style: style.id, page: wordPage[firstWord[index]], kind: kind, value: numbers[index], ayahID: index + 1
                    ))
                }
            }
            for sajdah in metadata.sajdahs {
                let id = ayahID[sajdah.ayah.description]!
                rows.markers.append(MarkerRow(
                    style: style.id, page: wordPage[markerWord[id - 1]], kind: "sajdah", value: sajdah.number, ayahID: id
                ))
            }
        }
        return rows
    }
}

struct AyahRecord {
    /// Global index 1…6236 in canonical order.
    let id: Int
    let surah: Int
    let ayah: Int
    /// Words joined by U+0020, without the end marker.
    let textHafs: String
}

struct StyleLayout {
    let id: String
    let rows: [LayoutRow]
}
