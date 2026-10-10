import Foundation
import QuranDataModel

/// Content packs: one read-only sqlite per translation, tafsir or surah-info edition, written to
/// `QuranData/out/<profile>/Packs/`. New packs are added in the profile only.
///
/// **No manifest ships** (QURAN_MIGRATION_PLAN.md, T15). Two profiles would write two manifests
/// to one committed path, so the app discovers packs by file prefix (`translation-`, `tafsir-`,
/// `surah-info-`) and reads each pack's own `pack` table — which is why that table carries the
/// Arabic names as well as the English ones. The manifest the build still writes is a report of
/// what it made (sizes and hashes), kept beside the folder rather than in it.
enum PackSchema {
    /// 2: `pack` gained `name_ar` and `author_ar`, so a pack describes itself without a manifest.
    static let schemaVersion = 2
    /// The report's format; it is not read by the app.
    static let manifestVersion = 2

    static let common = [
        "CREATE TABLE pack (id TEXT, kind TEXT, language TEXT, name TEXT, author TEXT, direction TEXT, version INT, source_url TEXT, license TEXT, name_ar TEXT, author_ar TEXT)",
        // Search text without footnote tokens; rowid = ayah id. Translation search UI: Phase 5.
        "CREATE VIRTUAL TABLE pack_fts USING fts5(text, content='', tokenize='unicode61 remove_diacritics 2')",
        "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)",
    ]

    static let translation = [
        // text: plain text with [[fn:ID]] tokens and *italics*; footnotes_json: {"ID": "note"}.
        "CREATE TABLE translation (ayah_id INT PRIMARY KEY, text TEXT, footnotes_json TEXT NULL)",
    ]

    /// One row per surah (1…114); pack_fts rowid = surah number.
    static let surahInfo = [
        "CREATE TABLE surah_info (surah INTEGER PRIMARY KEY, name TEXT NOT NULL, summary TEXT NOT NULL, html TEXT NOT NULL)",
    ]

    static let tafsir = [
        // Every ayah has a row; group_ayah_id is the group owner (= ayah_id for the owner), and
        // html (TafsirHTML's subset) is only on the owner row. pack_fts is keyed by the owner.
        "CREATE TABLE tafsir (ayah_id INT PRIMARY KEY, group_ayah_id INT NOT NULL, html TEXT NULL)",
        "CREATE INDEX tafsir_group ON tafsir (group_ayah_id)",
    ]
}

/// One entry of the pack report (sizes and hashes of what the build wrote).
struct PackManifestEntry: Codable {
    let id: String
    let kind: String
    let language: String
    /// Shown by the app in its UI language (ar / en).
    let nameEn: String
    let nameAr: String
    let authorEn: String
    let authorAr: String
    let direction: String
    let version: Int
    /// File name in the Packs folder.
    let file: String
    let bytes: Int
    let sha256: String
    let license: String

    private enum CodingKeys: String, CodingKey {
        case id, kind, language, direction, version, file, bytes, sha256, license
        case nameEn = "name_en", nameAr = "name_ar", authorEn = "author_en", authorAr = "author_ar"
    }
}

struct PackManifest: Codable {
    let schemaVersion: Int
    let packs: [PackManifestEntry]
}

/// A translation converted to the pack format, before it is written.
struct TranslationRows {
    /// By global ayah id (1…6236).
    var text: [Int: String] = [:]
    var footnotes: [Int: [String: String]] = [:]
}

/// Reads a QUL translation and converts every ayah. Keys are "surah:ayah" and are joined to
/// the global ayah ids by key, never by order.
func loadTranslation(_ pack: BuildConfig.Packs.Translation, config: BuildConfig, ayahIDs: [String: Int]) throws -> TranslationRows {
    guard pack.format == "footnote-tags" else { throw BuildError.data("\(pack.id): unsupported translation format '\(pack.format)'") }
    struct Entry: Decodable { let t: String; let f: [String: String]? }
    let raw = try JSONDecoder().decode([String: Entry].self, from: Data(contentsOf: config.input(pack.file).url))
    try require(Set(raw.keys) == Set(ayahIDs.keys), "\(pack.id): keys are not exactly the \(ayahIDs.count) ayahs")
    var rows = TranslationRows()
    for (key, entry) in raw {
        let converted: (text: String, footnotes: [String: String])
        do {
            converted = try TranslationMarkup.convertFootnoteTags(text: entry.t, footnotes: entry.f ?? [:])
        } catch {
            throw BuildError.data("\(pack.id) \(key): \(error)")
        }
        let id = ayahIDs[key]!
        try require(!converted.text.isEmpty, "\(pack.id) \(key): empty text")
        rows.text[id] = converted.text
        if !converted.footnotes.isEmpty { rows.footnotes[id] = converted.footnotes }
    }

    // The QUL simple export of the same translation must be our text without the footnotes.
    if let crossCheck = pack.crossCheck {
        let db = try SQLiteDatabase(path: config.input(crossCheck).url.path, readOnly: true)
        var checked = 0
        var differ: [String] = []
        try db.query("SELECT ayah_key, text FROM translation") { row in
            let key = row.text(0) ?? "", text = row.text(1) ?? ""
            checked += 1
            if let id = ayahIDs[key], TranslationMarkup.searchText(rows.text[id] ?? "") != TranslationMarkup.stripHTML(text) {
                differ.append(key)
            }
        }
        try require(checked == ayahIDs.count, "\(crossCheck): \(checked) rows")
        try require(differ.isEmpty, "\(pack.id): \(differ.count) ayahs differ from \(crossCheck), e.g. \(differ.prefix(5))")
    }
    return rows
}

/// Writes one translation pack and returns its manifest entry.
func writeTranslationPack(_ pack: BuildConfig.Packs.Translation, rows: TranslationRows, to directory: URL) throws -> PackManifestEntry {
    let header = PackHeader(id: pack.id, kind: "translation", language: pack.language,
                            nameEn: pack.nameEn, nameAr: pack.nameAr, authorEn: pack.authorEn, authorAr: pack.authorAr,
                            direction: pack.direction, version: pack.version, sourceURL: pack.sourceURL, license: pack.license)
    return try writePack(header, file: "translation-\(pack.id).sqlite", schema: PackSchema.translation, to: directory) { db in
        let insert = try db.prepare("INSERT INTO translation VALUES (?, ?, ?)")
        let search = try db.prepare("INSERT INTO pack_fts (rowid, text) VALUES (?, ?)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        for id in rows.text.keys.sorted() {
            let text = rows.text[id]!
            let notes = try rows.footnotes[id].map { String(decoding: try encoder.encode($0), as: UTF8.self) }
            try insert.run([.int(id), .text(text), SQLiteValue(notes)])
            try search.run([.int(id), .text(TranslationMarkup.searchText(text))])
        }
    }
}

/// A tafsir converted to the pack format, with what the conversion found.
struct TafsirRows {
    /// Every ayah id (1…6236) → its group owner's ayah id.
    var group: [Int: Int] = [:]
    /// Group owner id → sanitized HTML.
    var html: [Int: String] = [:]
    /// What sanitizing dropped or renamed, over the whole pack.
    var report = TafsirHTML.Report()
    /// Data observations, reported and not altered (README "Findings").
    var findings: [String] = []
    /// Extra provenance written to the pack's `meta` (a mirror's digest, its silent count).
    var meta: [(String, String)] = []

    var groupCount: Int { html.count }
}

/// Reads a QUL tafsir sqlite. Rows are joined to ayah ids by "surah:ayah", never by order.
/// Fails on anything that would leave an ayah without text: unknown keys, an owner without
/// text, a pointer with text, a pointer to an ayah that is not an owner, or HTML the sanitizer
/// cannot map. Groups that are not contiguous or span surahs are findings, not failures (the
/// app labels a group by its first and last ayah).
func loadTafsir(_ pack: BuildConfig.Packs.Tafsir, config: BuildConfig, ayahIDs: [String: Int]) throws -> TafsirRows {
    guard pack.format == "qul-sqlite" else { throw BuildError.data("\(pack.id): unsupported tafsir format '\(pack.format)'") }
    struct Raw { let key, group, from, to, keys, text: String }
    let db = try SQLiteDatabase(path: config.input(pack.file).url.path, readOnly: true)
    var raw: [Raw] = []
    try db.query("SELECT ayah_key, group_ayah_key, from_ayah, to_ayah, ayah_keys, text FROM tafsir") { row in
        raw.append(Raw(key: row.text(0) ?? "", group: row.text(1) ?? "", from: row.text(2) ?? "", to: row.text(3) ?? "",
                       keys: row.text(4) ?? "", text: row.text(5) ?? ""))
    }
    let keys = raw.map(\.key)
    try require(keys.count == ayahIDs.count && Set(keys) == Set(ayahIDs.keys), "\(pack.id): rows are not exactly the \(ayahIDs.count) ayahs (\(keys.count) rows, \(Set(keys).count) distinct)")
    let surahOf = Dictionary(uniqueKeysWithValues: ayahIDs.map { ($0.value, Int($0.key.split(separator: ":")[0])!) })
    let keyOf = Dictionary(uniqueKeysWithValues: ayahIDs.map { ($0.value, $0.key) })

    var rows = TafsirRows()
    var members: [Int: [Int]] = [:]
    var rangeColumns: [Int: (from: String, to: String, keys: [String])] = [:]
    for entry in raw {
        let id = ayahIDs[entry.key]!
        guard let owner = ayahIDs[entry.group] else { throw BuildError.data("\(pack.id) \(entry.key): group \(entry.group) is not an ayah") }
        rows.group[id] = owner
        members[owner, default: []].append(id)
        let hasText = !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if owner == id {
            try require(hasText, "\(pack.id) \(entry.key): group owner without text")
            do {
                let sanitized = try TafsirHTML.sanitize(entry.text)
                rows.html[id] = sanitized.html
                rows.report.merge(sanitized.report)
            } catch {
                throw BuildError.data("\(pack.id) \(entry.key): \(error)")
            }
            // QUL's own range columns on the owner, compared with the rows that point to it below.
            let listed = entry.keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            rangeColumns[id] = (entry.from, entry.to, listed)
        } else {
            try require(!hasText, "\(pack.id) \(entry.key): points to \(entry.group) but has text of its own")
        }
    }
    for (id, owner) in rows.group where rows.html[owner] == nil {
        throw BuildError.data("\(pack.id) \(keyOf[id]!): group \(keyOf[owner]!) has no text (it points elsewhere)")
    }

    for (owner, ids) in members.sorted(by: { $0.key < $1.key }) {
        let sorted = ids.sorted()
        let key = keyOf[owner]!
        if sorted != Array(sorted.first!...sorted.last!) { rows.findings.append("\(key): group is not contiguous (\(sorted.map { keyOf[$0]! }))") }
        if Set(sorted.map { surahOf[$0]! }).count > 1 { rows.findings.append("\(key): group spans surahs (\(keyOf[sorted.first!]!)–\(keyOf[sorted.last!]!))") }
        if sorted.first != owner { rows.findings.append("\(key): owner is not the group's first ayah") }
        if let columns = rangeColumns[owner] {
            let names = sorted.map { keyOf[$0]! }
            if columns.from != names.first || columns.to != names.last || (!columns.keys.isEmpty && columns.keys != names) {
                rows.findings.append("\(key): from/to/ayah_keys (\(columns.from)–\(columns.to)) differ from the rows that point here (\(names.first!)–\(names.last!))")
            }
        }
    }

    // Arabic letters outside an Arabic run in a left-to-right pack are drawn in the pack's font,
    // not KFGQPC Hafs: report where.
    if pack.direction == "ltr" {
        for (owner, html) in rows.html.sorted(by: { $0.key < $1.key }) {
            let outside = html.replacing(/<(span|div) lang="ar"[^>]*>[^<]*<\/(span|div)>/, with: "")
            let arabic = outside.unicodeScalars.filter { (0x0600...0x06FF).contains($0.value) || (0x0750...0x077F).contains($0.value) || (0xFB50...0xFDFF).contains($0.value) || (0xFE70...0xFEFF).contains($0.value) }
            if !arabic.isEmpty {
                let codes = arabic.map { String(format: "U+%04X", $0.value) }
                rows.findings.append("\(keyOf[owner]!): Arabic outside an Arabic run: \(codes.joined(separator: " "))")
            }
        }
    }
    return rows
}

/// Writes one tafsir pack and returns its manifest entry.
func writeTafsirPack(_ pack: BuildConfig.Packs.Tafsir, rows: TafsirRows, to directory: URL) throws -> PackManifestEntry {
    let file = "tafsir-\(pack.id).sqlite"
    let header = PackHeader(id: pack.id, kind: "tafsir", language: pack.language,
                            nameEn: pack.nameEn, nameAr: pack.nameAr, authorEn: pack.authorEn, authorAr: pack.authorAr,
                            direction: pack.direction, version: pack.version, sourceURL: pack.sourceURL, license: pack.license)
    return try writePack(header, file: file, schema: PackSchema.tafsir, meta: rows.meta, to: directory) { db in
        let insert = try db.prepare("INSERT INTO tafsir VALUES (?, ?, ?)")
        let search = try db.prepare("INSERT INTO pack_fts (rowid, text) VALUES (?, ?)")
        for id in rows.group.keys.sorted() {
            let owner = rows.group[id]!
            let html = id == owner ? rows.html[id] : nil
            try insert.run([.int(id), .int(owner), SQLiteValue(html)])
            if let html { try search.run([.int(id), .text(TafsirHTML.plainText(html))]) }
        }
    }
}

/// The `pack` row and manifest fields every pack shares.
struct PackHeader {
    let id, kind, language: String
    let nameEn, nameAr, authorEn, authorAr: String
    let direction: String
    let version: Int
    let sourceURL, license: String
}

/// Creates `file` with the common tables plus `schema`, fills it in one transaction, indexes
/// and vacuums it, and returns its manifest entry.
func writePack(
    _ header: PackHeader, file: String, schema: [String], meta extra: [(String, String)] = [],
    to directory: URL, rows: (SQLiteDatabase) throws -> Void
) throws -> PackManifestEntry {
    let url = directory.appendingPathComponent(file)
    try? FileManager.default.removeItem(at: url)
    let db = try SQLiteDatabase(path: url.path, readOnly: false)
    try db.execute("PRAGMA journal_mode = DELETE")
    for statement in PackSchema.common + schema { try db.execute(statement) }
    try db.transaction {
        try db.prepare("INSERT INTO pack VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)").run([
            .text(header.id), .text(header.kind), .text(header.language), .text(header.nameEn), .text(header.authorEn),
            .text(header.direction), .int(header.version), .text(header.sourceURL), .text(header.license),
            .text(header.nameAr), .text(header.authorAr),
        ])
        try rows(db)
        let meta = try db.prepare("INSERT INTO meta VALUES (?, ?)")
        try meta.run([.text("schema_version"), .text(String(PackSchema.schemaVersion))])
        try meta.run([.text("generator"), .text("Tools/QuranBuilder")])
        for (key, value) in extra { try meta.run([.text(key), .text(value)]) }
    }
    try db.execute("INSERT INTO pack_fts (pack_fts) VALUES ('optimize')")
    try db.execute("VACUUM")
    let bytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    return PackManifestEntry(
        id: header.id, kind: header.kind, language: header.language,
        nameEn: header.nameEn, nameAr: header.nameAr, authorEn: header.authorEn, authorAr: header.authorAr,
        direction: header.direction, version: header.version, file: file, bytes: bytes,
        sha256: try SourceManifest.sha256(of: url), license: header.license
    )
}

/// A surah-info resource converted to the pack format.
struct SurahInfoRows {
    struct Row { let name: String; let summary: String; let html: String }
    /// By surah number, 1…114.
    var rows: [Int: Row] = [:]
    var report = TafsirHTML.Report()
}

/// Reads QUL's surah information JSON. Keys must be exactly the 114 surah numbers, each entry's
/// `surah_number` must match its key, and the HTML must sanitize (same subset as tafsir).
func loadSurahInfo(_ pack: BuildConfig.Packs.SurahInfo, config: BuildConfig) throws -> SurahInfoRows {
    guard pack.format == "qul-surah-info-json" else { throw BuildError.data("\(pack.id): unsupported surah info format '\(pack.format)'") }
    struct Entry: Decodable {
        let surah_number: Int
        let surah_name: String
        let text: String
        let short_text: String?
    }
    let raw = try JSONDecoder().decode([String: Entry].self, from: Data(contentsOf: config.input(pack.file).url))
    try require(Set(raw.keys) == Set((1...114).map(String.init)), "\(pack.id): keys are not exactly surahs 1…114")
    var result = SurahInfoRows()
    for (key, entry) in raw {
        try require(String(entry.surah_number) == key, "\(pack.id) \(key): surah_number \(entry.surah_number)")
        do {
            let sanitized = try TafsirHTML.sanitize(entry.text)
            result.report.merge(sanitized.report)
            let summary = (entry.short_text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            result.rows[entry.surah_number] = SurahInfoRows.Row(
                name: entry.surah_name, summary: summary.isEmpty ? TafsirHTML.plainText(sanitized.html) : summary, html: sanitized.html
            )
        } catch {
            throw BuildError.data("\(pack.id) \(key): \(error)")
        }
    }
    return result
}

func writeSurahInfoPack(_ pack: BuildConfig.Packs.SurahInfo, rows: SurahInfoRows, to directory: URL) throws -> PackManifestEntry {
    let header = PackHeader(id: pack.id, kind: "surah-info", language: pack.language,
                            nameEn: pack.nameEn, nameAr: pack.nameAr, authorEn: pack.authorEn, authorAr: pack.authorAr,
                            direction: pack.direction, version: pack.version, sourceURL: pack.sourceURL, license: pack.license)
    return try writePack(header, file: "\(pack.id).sqlite", schema: PackSchema.surahInfo, to: directory) { db in
        let insert = try db.prepare("INSERT INTO surah_info VALUES (?, ?, ?, ?)")
        let search = try db.prepare("INSERT INTO pack_fts (rowid, text) VALUES (?, ?)")
        for surah in rows.rows.keys.sorted() {
            let row = rows.rows[surah]!
            try insert.run([.int(surah), .text(row.name), .text(row.summary), .text(row.html)])
            try search.run([.int(surah), .text(TafsirHTML.plainText(row.html))])
        }
    }
}

/// Builds every pack in the profile into `packs.directory` and writes the report. Files of packs
/// no longer listed are removed, so the folder holds exactly what the report names.
func buildPacks(_ config: BuildConfig, ayahIDs: [String: Int]) async throws -> PackManifest {
    guard let packs = config.packs else { return PackManifest(schemaVersion: PackSchema.manifestVersion, packs: []) }
    let directory = config.path(packs.directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var entries: [PackManifestEntry] = []
    for pack in packs.translations {
        let rows = try loadTranslation(pack, config: config, ayahIDs: ayahIDs)
        entries.append(try writeTranslationPack(pack, rows: rows, to: directory))
    }
    var tafsirs: [(BuildConfig.Packs.Tafsir, TafsirRows)] = []
    for pack in packs.tafsirs { tafsirs.append((pack, try loadTafsir(pack, config: config, ayahIDs: ayahIDs))) }
    for pack in packs.mirroredTafsirs {
        tafsirs.append((pack.header, try await loadMirroredTafsir(pack, config: config, ayahIDs: ayahIDs)))
    }
    for (pack, rows) in tafsirs {
        print("tafsir \(pack.id): \(rows.group.count) ayahs in \(rows.groupCount) groups (\(rows.group.count - rows.groupCount) ayahs share their group's text, \(ayahIDs.count - rows.group.count) have no note)")
        print("  sanitized HTML: \(rows.report.isEmpty ? "nothing dropped or renamed" : "\(rows.report.lines.count) changes")")
        for line in rows.report.lines { print("    " + line) }
        print("  findings: \(rows.findings.isEmpty ? "none" : "\(rows.findings.count)")")
        for finding in rows.findings { print("    " + finding) }
        entries.append(try writeTafsirPack(pack, rows: rows, to: directory))
    }
    for pack in packs.surahInfo {
        let rows = try loadSurahInfo(pack, config: config)
        print("surah info \(pack.id): \(rows.rows.count) surahs")
        print("  sanitized HTML: \(rows.report.isEmpty ? "nothing dropped or renamed" : "\(rows.report.lines.count) changes")")
        for line in rows.report.lines { print("    " + line) }
        entries.append(try writeSurahInfoPack(pack, rows: rows, to: directory))
    }
    try require(Set(entries.map(\.id)).count == entries.count, "duplicate pack ids")
    try require(entries.allSatisfy { ["translation-", "tafsir-", "surah-info-"].contains(where: $0.file.hasPrefix) },
                "a pack file without a kind prefix cannot be discovered by the app")
    let keep = Set(entries.map(\.file))
    for name in try FileManager.default.contentsOfDirectory(atPath: directory.path) where !keep.contains(name) && !name.hasPrefix(".") {
        try FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
    let manifest = PackManifest(schemaVersion: PackSchema.manifestVersion, packs: entries)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let report = config.path(packs.report)
    try FileManager.default.createDirectory(at: report.deletingLastPathComponent(), withIntermediateDirectories: true)
    try encoder.encode(manifest).write(to: report)
    return manifest
}
