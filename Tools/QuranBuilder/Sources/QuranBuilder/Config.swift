import Foundation

/// The two input profiles. Both write the same schema; what differs is what goes into it.
enum Profile: String, Decodable {
    /// Tanzil's Uthmani text and metadata. No page layout, no glyphs: the public build.
    case tanzil
    /// The QUL downloads in `QuranData/raw`: the full KFGQPC V2 Mushaf. Local only.
    case qul
}

/// `Tools/QuranBuilder/profiles/<profile>.json`: which inputs go into which outputs.
///
/// Paths are relative to the config file's folder, except QUL inputs, which are relative to
/// `raw` because that is how `QuranData/SOURCES.md` lists them.
struct BuildConfig: Decodable {

    // MARK: Tanzil

    /// One Tanzil text download, pinned by the SHA-256 of its verses rather than of the file:
    /// the file's copyright block carries the current year and so changes on its own every
    /// January. An upstream revision of the text is then a loud failure to be read and re-pinned
    /// deliberately, never a silent change to the Quran the app ships.
    struct TanzilText: Decodable {
        let url: String
        /// Where the download is kept, so a rebuild reads the same bytes offline.
        let cache: String
        /// SHA-256 of the verses joined as `sura|aya|text` lines.
        let verseDigest: String
    }

    struct TanzilMetadata: Decodable {
        let url: String
        let cache: String
    }

    struct Tanzil: Decodable {
        /// What is displayed: the Uthmani text, stored verbatim once the basmala is lifted off.
        let text: TanzilText
        /// What is searched: the same verses in modern (imla'i) spelling, the Simple Clean text.
        let searchText: TanzilText
        /// `quran-data.xml`: surahs, juz, quarters, manzils, rukus and sajdas.
        let metadata: TanzilMetadata
    }

    // MARK: QUL

    struct Words: Decodable {
        let hafs: String
        let glyphV2: String
    }

    /// QUL range tables (first_verse_key, last_verse_key, verse_mapping) and the sajda list.
    struct Metadata: Decodable {
        let juz: String
        let hizb: String
        let rub: String
        let manzil: String
        let ruku: String
        let sajda: String
    }

    /// Fonts copied unchanged from `raw` for the app to bundle.
    struct Fonts: Decodable {
        /// Destination folder, relative to the config file.
        let bundleDirectory: String
        let files: [String]
    }

    /// One TTF per page (QPC V2), checked file by file against a `shasum` manifest.
    struct PageFonts: Decodable {
        let style: String
        /// Folder of `p1.ttf…p<count>.ttf`, relative to `raw`.
        let directory: String
        /// `shasum -a 256` output for the folder, relative to `raw`; itself listed in SOURCES.md.
        let manifest: String
        let count: Int
        /// Destination folder (a folder reference in the app target), relative to the config file.
        let bundleDirectory: String
    }

    struct Style: Decodable {
        /// `MushafStyleID` raw value in the app, stored in `mushaf_line.style`.
        let id: String
        let layout: String
    }

    struct QUL: Decodable {
        /// `QuranData/SOURCES.md`, relative to the config file: the hash of every raw input.
        let sources: String
        /// `QuranData/raw`, relative to the config file.
        let raw: String
        let surahs: String
        /// Ayah metadata (global id, verse key, word count), used as a cross-check.
        let ayahs: String
        /// Imlaei simple text (no diacritics), indexed for search.
        let imlaei: String
        let metadata: Metadata
        let words: Words
        let styles: [Style]
        let fonts: Fonts
        /// QUL ligature tables by font id (stored as `font_ligature.font`): name → table file.
        let ligatures: [String: String]
        let pageFonts: [PageFonts]
    }

    // MARK: Shared

    /// The size budget for everything the profile puts in the app bundle (T6).
    struct SizeReportConfig: Decodable {
        /// Folders measured, relative to the config file; each is one heading in the report.
        let paths: [String]
        let budgetCompressedMB: Int
        let budgetInstalledMB: Int
    }

    /// Hand-kept lists, checked against the built ayahs.
    struct Curated: Decodable {
        /// `data/ayah-of-the-day.txt`, relative to the config file.
        let ayahOfTheDay: String
        /// The JSON the app will bundle, relative to the config file.
        let ayahOfTheDayOutput: String
        /// No entry may come back within this many days, so the list needs as many entries.
        let minimumEntries: Int
    }

    let profile: Profile
    /// The database, relative to the config file.
    let output: String
    let tanzil: Tanzil?
    let qul: QUL?
    let curated: Curated?
    let sizeReport: SizeReportConfig

    /// Folder holding the config file.
    private(set) var base = URL(fileURLWithPath: ".")

    private enum CodingKeys: String, CodingKey {
        case profile, output, tanzil, qul, curated, sizeReport
    }

    static func load(path: String) throws -> BuildConfig {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let decoder = JSONDecoder()
        // `name_en` → `nameEn`; the camel-case keys have no underscores and are unchanged.
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        var config = try decoder.decode(BuildConfig.self, from: Data(contentsOf: url))
        config.base = url.deletingLastPathComponent()
        switch config.profile {
        case .tanzil: try require(config.tanzil != nil, "profile tanzil needs a \"tanzil\" section")
        case .qul: try require(config.qul != nil, "profile qul needs a \"qul\" section")
        }
        return config
    }

    func path(_ path: String) -> URL {
        path.hasPrefix("/") ? URL(fileURLWithPath: path) : base.appendingPathComponent(path).standardizedFileURL
    }

    /// A QUL input: its path as SOURCES.md lists it, and where it is on disk.
    func input(_ relative: String) -> InputFile {
        InputFile(relativePath: relative, url: path(qul!.raw).appendingPathComponent(relative))
    }

    /// Every raw QUL input this config reads, for hash verification.
    var qulInputs: [InputFile] {
        guard let qul else { return [] }
        let m = qul.metadata
        let tables = [m.juz, m.hizb, m.rub, m.manzil, m.ruku, m.sajda]
        let fontInputs = qul.fonts.files + qul.ligatures.keys.sorted().map { qul.ligatures[$0]! }
            + qul.pageFonts.map(\.manifest)
        return ([qul.surahs, qul.ayahs, qul.imlaei, qul.words.hafs, qul.words.glyphV2] + tables
            + qul.styles.map(\.layout) + fontInputs).map(input)
    }
}

struct InputFile {
    /// Relative to `QuranData/raw/`, as written in SOURCES.md.
    let relativePath: String
    let url: URL
}
