import Foundation
import QuranDataModel

enum BuildError: Error, CustomStringConvertible {
    case usage
    case data(String)

    var description: String {
        switch self {
        case .usage: "usage: QuranBuilder --profile tanzil|qul   (or --config <path/to/profile.json>)"
        case .data(let message): "data: \(message)"
        }
    }
}

func require(_ condition: Bool, _ message: @autoclosure () -> String) throws {
    if !condition { throw BuildError.data(message()) }
}

// MARK: Hashes

/// Checks every input against SOURCES.md and returns the verified hashes by path.
func verifyInputs(_ inputs: [InputFile], manifest: SourceManifest) throws -> [String: String] {
    var verified: [String: String] = [:]
    for input in inputs {
        verified[input.relativePath] = try manifest.verify(path: input.relativePath, url: input.url)
    }
    return verified
}

// MARK: Words

/// One entry of the QUL word-by-word scripts: a word, or an ayah's end marker.
struct Word {
    /// QUL word id; the layout's first_word_id/last_word_id refer to it.
    let id: Int
    let surah: Int
    let ayah: Int
    /// 1-based position in the ayah; the end marker is last.
    let position: Int
    /// KFGQPC Hafs text. The marker is the ayah number in Arabic-Indic digits.
    let hafs: String
    /// QPC V2 glyph code (drawn with the page's own font).
    let glyphV2: String

    var isMarker: Bool {
        !hafs.isEmpty && hafs.unicodeScalars.allSatisfy { (0x0660...0x0669).contains($0.value) }
    }
}

private struct RawWord: Decodable {
    let id: Int
    let surah: String
    let ayah: String
    let word: String
    let text: String
}

/// Joins the Hafs and V2 glyph word-by-word scripts on word id. Both must have the same
/// keys ("s:a:w"), ids and positions; anything else stops the build.
func loadWords(hafs: URL, glyphV2: URL) throws -> [Word] {
    let decoder = JSONDecoder()
    let hafsWords = try decoder.decode([String: RawWord].self, from: Data(contentsOf: hafs))
    let glyphWords = try decoder.decode([String: RawWord].self, from: Data(contentsOf: glyphV2))
    try require(Set(hafsWords.keys) == Set(glyphWords.keys), "Hafs and V2 word keys differ")

    var words: [Word] = []
    words.reserveCapacity(hafsWords.count)
    for (key, word) in hafsWords {
        let glyph = glyphWords[key]!
        try require(word.id == glyph.id, "\(key): Hafs id \(word.id), V2 id \(glyph.id)")
        guard let surah = Int(word.surah), let ayah = Int(word.ayah), let position = Int(word.word) else {
            throw BuildError.data("\(key): non-numeric location")
        }
        try require("\(surah):\(ayah):\(position)" == key, "\(key): location fields disagree with the key")
        try require((word.surah, word.ayah, word.word) == (glyph.surah, glyph.ayah, glyph.word), "\(key): V2 location differs")
        words.append(Word(id: word.id, surah: surah, ayah: ayah, position: position, hafs: word.text, glyphV2: glyph.text))
    }
    words.sort { $0.id < $1.id }
    try require(words.map(\.id) == Array(1...words.count), "word ids are not 1…\(words.count)")
    return words
}

// MARK: Layout

struct LayoutRow {
    let page: Int
    let line: Int
    /// 'ayah' | 'surah_name' | 'basmallah', as in the QUL file.
    let kind: String
    let isCentered: Bool
    let firstWord: Int?
    let lastWord: Int?
    let surah: Int?
}

/// The QUL layout stores '' (not NULL) in first_word_id/last_word_id/surah_number where
/// they do not apply. Treat '' as absent; any other non-integer is an error.
private func integerOrAbsent(_ value: SQLiteValue, _ context: @autoclosure () -> String) throws -> Int? {
    switch value {
    case .int(let int): return int
    case .null, .text(""): return nil
    case .text(let text): throw BuildError.data("\(context()): unexpected value '\(text)'")
    }
}

func loadLayout(path: URL) throws -> [LayoutRow] {
    let db = try SQLiteDatabase(path: path.path, readOnly: true)
    var rows: [LayoutRow] = []
    try db.query("""
        SELECT page_number, line_number, line_type, is_centered, first_word_id, last_word_id, surah_number
        FROM pages ORDER BY page_number, line_number
        """) { row in
        let page = row.int(0) ?? 0, line = row.int(1) ?? 0
        let where_ = "page \(page) line \(line)"
        rows.append(LayoutRow(
            page: page,
            line: line,
            kind: row.text(2) ?? "",
            isCentered: (row.int(3) ?? 0) != 0,
            firstWord: try integerOrAbsent(row.value(4), where_),
            lastWord: try integerOrAbsent(row.value(5), where_),
            surah: try integerOrAbsent(row.value(6), where_)
        ))
    }
    return rows
}

// MARK: Surahs

struct SurahRecord: Decodable {
    let id: Int
    let name: String
    let nameSimple: String
    let nameArabic: String
    let revelationOrder: Int
    let revelationPlace: String
    let versesCount: Int
    let bismillahPre: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name
        case nameSimple = "name_simple"
        case nameArabic = "name_arabic"
        case revelationOrder = "revelation_order"
        case revelationPlace = "revelation_place"
        case versesCount = "verses_count"
        case bismillahPre = "bismillah_pre"
    }
}

func loadSurahs(path: URL) throws -> [SurahRecord] {
    let raw = try JSONDecoder().decode([String: SurahRecord].self, from: Data(contentsOf: path))
    let surahs = raw.values.sorted { $0.id < $1.id }
    try require(surahs.map(\.id) == Array(1...114), "surah metadata is not 1…114")
    return surahs
}

// MARK: Metadata

/// An ayah reference "surah:ayah".
struct AyahKey: Hashable, Comparable, CustomStringConvertible {
    let surah: Int
    let ayah: Int

    init(surah: Int, ayah: Int) {
        self.surah = surah
        self.ayah = ayah
    }

    init(_ text: String) throws {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { throw BuildError.data("bad verse key '\(text)'") }
        self.init(surah: parts[0], ayah: parts[1])
    }

    static func < (lhs: AyahKey, rhs: AyahKey) -> Bool { (lhs.surah, lhs.ayah) < (rhs.surah, rhs.ayah) }
    var description: String { "\(surah):\(ayah)" }
}

/// One juz, hizb, rub, manzil or ruku from QUL: its number and the ayahs it covers.
struct RangeUnit {
    let number: Int
    let first: AyahKey
    let last: AyahKey
    /// From verse_mapping: surah → ayah range.
    let mapping: [Int: ClosedRange<Int>]
}

/// Loads a QUL range table keyed by number, e.g. `{"1": {"juz_number": 1, "first_verse_key": "1:1",
/// "last_verse_key": "2:141", "verse_mapping": {"1": "1-7", "2": "1-141"}}}`.
func loadRanges(path: URL, numberKey: String) throws -> [RangeUnit] {
    guard let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: [String: Any]] else {
        throw BuildError.data("\(path.lastPathComponent): not an object of objects")
    }
    var units: [RangeUnit] = []
    for (key, value) in raw {
        guard let number = value[numberKey] as? Int, String(number) == key,
              let first = value["first_verse_key"] as? String, let last = value["last_verse_key"] as? String,
              let mapping = value["verse_mapping"] as? [String: String]
        else { throw BuildError.data("\(path.lastPathComponent) entry \(key): unexpected shape") }
        var ranges: [Int: ClosedRange<Int>] = [:]
        for (surah, range) in mapping {
            let bounds = range.split(separator: "-").compactMap { Int($0) }
            guard let surahNumber = Int(surah), (1...2).contains(bounds.count) else {
                throw BuildError.data("\(path.lastPathComponent) entry \(key): bad mapping \(surah): \(range)")
            }
            ranges[surahNumber] = bounds[0]...bounds[bounds.count - 1]
        }
        units.append(RangeUnit(number: number, first: try AyahKey(first), last: try AyahKey(last), mapping: ranges))
    }
    units.sort { $0.number < $1.number }
    try require(units.map(\.number) == Array(1...units.count), "\(path.lastPathComponent): numbers are not 1…\(units.count)")
    return units
}

struct Sajdah {
    let number: Int
    let ayah: AyahKey
    /// As given by QUL: "optional" or "required".
    let type: String
}

func loadSajdahs(path: URL) throws -> [Sajdah] {
    struct Raw: Decodable { let sajdah_number: Int; let verse_key: String; let sajdah_type: String }
    let raw = try JSONDecoder().decode([String: Raw].self, from: Data(contentsOf: path))
    return try raw.values.map { Sajdah(number: $0.sajdah_number, ayah: try AyahKey($0.verse_key), type: $0.sajdah_type) }
        .sorted { $0.number < $1.number }
}

/// One entry of QUL's ayah-level files: Imlaei text (keyed "s:a") or ayah metadata (keyed by id).
struct AyahEntry {
    let id: Int
    let key: AyahKey
    let text: String
    let wordsCount: Int?
}

func loadAyahEntries(path: URL) throws -> [AyahEntry] {
    struct Raw: Decodable { let id: Int; let verse_key: String; let text: String; let words_count: Int? }
    let raw = try JSONDecoder().decode([String: Raw].self, from: Data(contentsOf: path))
    var entries: [AyahEntry] = []
    for (key, value) in raw {
        try require(key == value.verse_key || key == String(value.id),
                    "\(path.lastPathComponent): key \(key) has id \(value.id), verse_key \(value.verse_key)")
        entries.append(AyahEntry(id: value.id, key: try AyahKey(value.verse_key), text: value.text, wordsCount: value.words_count))
    }
    return entries.sorted { $0.id < $1.id }
}

/// The QUL range tables, sajdahs and ayah-level files, on top of words, surahs and layouts.
struct QuranMetadataInput {
    /// Range tables by kind: "juz", "hizb", "rub", "manzil", "ruku".
    let ranges: [String: [RangeUnit]]
    let sajdahs: [Sajdah]
    let imlaei: [AyahEntry]
    let ayahMetadata: [AyahEntry]

    static func load(_ config: BuildConfig) throws -> QuranMetadataInput {
        let qul = config.qul!
        let m = qul.metadata
        let tables = [("juz", m.juz), ("hizb", m.hizb), ("rub", m.rub), ("manzil", m.manzil), ("ruku", m.ruku)]
        var ranges: [String: [RangeUnit]] = [:]
        for (kind, path) in tables {
            ranges[kind] = try loadRanges(path: config.input(path).url, numberKey: "\(kind)_number")
        }
        return QuranMetadataInput(
            ranges: ranges,
            sajdahs: try loadSajdahs(path: config.input(m.sajda).url),
            imlaei: try loadAyahEntries(path: config.input(qul.imlaei).url),
            ayahMetadata: try loadAyahEntries(path: config.input(qul.ayahs).url)
        )
    }
}
