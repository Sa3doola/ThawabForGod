import Foundation
import QuranDataModel

// MARK: Ligature tables

/// One QUL ligature table (`surah-header-ligatures.json`, …): name → the string that draws it.
struct LigatureTable {
    /// Font id from the profile, stored in `font_ligature.font`.
    let font: String
    /// Values with surrounding whitespace removed (QUL's values end in a space).
    let entries: [String: String]
    /// How many values had whitespace removed (reported as a finding).
    let trimmedCount: Int
}

func loadLigatures(_ config: BuildConfig) throws -> [LigatureTable] {
    let qul = config.qul!
    return try qul.ligatures.keys.sorted().map { font in
        let path = config.input(qul.ligatures[font]!).url
        let raw = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: path))
        var entries: [String: String] = [:]
        var trimmed = 0
        for (name, value) in raw {
            let clean = value.trimmingCharacters(in: .whitespaces)
            try require(!clean.isEmpty, "\(font) ligature \(name): empty value")
            if clean != value { trimmed += 1 }
            entries[name] = clean
        }
        return LigatureTable(font: font, entries: entries, trimmedCount: trimmed)
    }
}

/// The surah header and name tables must name every surah exactly once ("surah-1"…"surah-114").
/// Each header is a single code point (one colour glyph draws frame and name).
func checkSurahLigatures(_ tables: [LigatureTable]) throws {
    let expected = Set((1...114).map { "surah-\($0)" })
    for font in ["surah-header", "surah-name-v2"] {
        guard let table = tables.first(where: { $0.font == font }) else { throw BuildError.data("no ligature table for \(font)") }
        try require(Set(table.entries.keys) == expected, "\(font): keys are not surah-1…surah-114")
        try require(Set(table.entries.values).count == 114, "\(font): two surahs share a value")
        if font == "surah-header" {
            let multi = table.entries.filter { $0.value.unicodeScalars.count != 1 }.keys.sorted()
            try require(multi.isEmpty, "surah-header: not one code point: \(multi)")
        }
    }
}

// MARK: Bundled fonts

/// Copies the fonts listed in the profile into their bundle folder. Inputs were verified
/// against SOURCES.md before this runs; each copy is hashed again so a partial or stale copy
/// cannot pass.
func copyBundledFonts(_ config: BuildConfig, verified: [String: String]) throws -> [(name: String, bytes: Int)] {
    let fonts = config.qul!.fonts
    let destination = config.path(fonts.bundleDirectory)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    var copied: [(String, Int)] = []
    for file in fonts.files {
        let source = config.input(file)
        guard let expected = verified[file] else { throw BuildError.data("\(file) was not verified") }
        let target = destination.appendingPathComponent(source.url.lastPathComponent)
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: source.url, to: target)
        // Some QUL downloads are 0600; bundle resources are plain readable files.
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: target.path)
        let actual = try SourceManifest.sha256(of: target)
        try require(actual == expected, "\(target.path): copied file hashes to \(actual), expected \(expected)")
        let bytes = (try FileManager.default.attributesOfItem(atPath: target.path)[.size] as? Int) ?? 0
        copied.append((target.lastPathComponent, bytes))
    }
    return copied
}

// MARK: Page fonts

/// Parses `shasum -a 256` output: "<hash>  <path>" per line.
func loadShasumManifest(_ url: URL) throws -> [String: String] {
    var hashes: [String: String] = [:]
    for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
        let parts = line.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, parts[0].count == 64 else { throw BuildError.data("\(url.lastPathComponent): bad line '\(line)'") }
        hashes[parts[1].trimmingCharacters(in: .whitespaces)] = String(parts[0])
    }
    return hashes
}

/// Copies the page fonts (`p1.ttf…`) into the bundle folder. Every source file must be in the
/// manifest with the right hash, the manifest must list exactly these files, and every copy is
/// hashed again. The destination is replaced as a whole, so no stale file survives.
func copyPageFonts(_ fonts: BuildConfig.PageFonts, config: BuildConfig) throws -> (files: Int, bytes: Int) {
    let manifest = try loadShasumManifest(config.input(fonts.manifest).url)
    let names = (1...fonts.count).map { "p\($0).ttf" }
    let expectedPaths = Set(names.map { "\(fonts.directory)/\($0)" })
    try require(Set(manifest.keys) == expectedPaths, "\(fonts.manifest) does not list exactly \(fonts.directory)/p1…p\(fonts.count).ttf")

    let destination = config.path(fonts.bundleDirectory)
    try? FileManager.default.removeItem(at: destination)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    var bytes = 0
    for name in names {
        let path = "\(fonts.directory)/\(name)"
        let source = config.input(path).url
        let expected = manifest[path]!
        let actual = try SourceManifest.sha256(of: source)
        try require(actual == expected, "\(path): manifest has \(expected), the file is \(actual)")
        let target = destination.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: target)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: target.path)
        try require(try SourceManifest.sha256(of: target) == expected, "\(target.path): copy does not match the manifest")
        bytes += (try FileManager.default.attributesOfItem(atPath: target.path)[.size] as? Int) ?? 0
    }
    return (names.count, bytes)
}
