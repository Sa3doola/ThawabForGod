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

    // MARK: Packs

    /// Translation, tafsir and surah-info packs: one sqlite each in `directory`.
    struct Packs: Decodable {
        struct Translation: Decodable {
            let id: String
            let language: String
            let nameEn: String
            let nameAr: String
            let authorEn: String
            let authorAr: String
            let direction: String
            let version: Int
            let sourceURL: String
            let license: String
            /// QUL shape of `file`: "footnote-tags" (keyed "s:a" → {t, f}).
            let format: String
            /// Relative to `qul.raw`, as SOURCES.md lists it.
            let file: String
            /// Optional QUL "simple" sqlite of the same translation (translation(sura, ayah,
            /// ayah_key, text)): its text must equal ours with the footnote tokens removed.
            let crossCheck: String?
        }

        /// A QUL tafsir: grouped entries, HTML sanitized to the app's subset.
        struct Tafsir: Decodable {
            let id: String
            let language: String
            let nameEn: String
            let nameAr: String
            let authorEn: String
            let authorAr: String
            let direction: String
            let version: Int
            let sourceURL: String
            let license: String
            /// QUL shape of `file`: "qul-sqlite" (tafsir(ayah_key, group_ayah_key, from_ayah,
            /// to_ayah, ayah_keys, text); only the group owner carries the text).
            let format: String
            let file: String
        }

        /// A public-domain tafsir read from a mirror, pinned by the digest of its notes. One note
        /// per ayah, no groups, and **no row for an ayah the commentary passes over**: that
        /// absence is the commentary's own answer, which the app shows as "no note here".
        struct MirroredTafsir: Decodable {
            let id: String
            let language: String
            let nameEn: String
            let nameAr: String
            let authorEn: String
            let authorAr: String
            let direction: String
            let version: Int
            /// The mirror's folder of per-surah JSON (`<url>/<n>.json`).
            let sourceURL: String
            let license: String
            /// "spa5k-json": `[{surah, ayah, text}]` per surah.
            let format: String
            /// Where the 114 downloads are kept, relative to the config file.
            let cache: String
            /// SHA-256 of the notes joined as `surah|ayah|text` lines, in Quran order.
            let textDigest: String
            /// How many ayahs the commentary passes over. Pinned: a change is a change in the
            /// commentary, to be read rather than absorbed.
            let silentCount: Int

            /// The pack row and file name, as a QUL tafsir would have them.
            var header: Tafsir {
                Tafsir(id: id, language: language, nameEn: nameEn, nameAr: nameAr, authorEn: authorEn,
                       authorAr: authorAr, direction: direction, version: version, sourceURL: sourceURL,
                       license: license, format: format, file: "")
            }
        }

        /// Surah introductions: one HTML text per surah, sanitized like tafsir.
        struct SurahInfo: Decodable {
            let id: String
            let language: String
            let nameEn: String
            let nameAr: String
            let authorEn: String
            let authorAr: String
            let direction: String
            let version: Int
            let sourceURL: String
            let license: String
            /// QUL shape of `file`: "qul-surah-info-json".
            let format: String
            let file: String
        }

        /// Output folder, relative to the config file.
        let directory: String
        /// The JSON report of what was written (not bundled), relative to the config file.
        let report: String
        let translations: [Translation]
        let tafsirs: [Tafsir]
        let mirroredTafsirs: [MirroredTafsir]
        let surahInfo: [SurahInfo]

        private enum CodingKeys: String, CodingKey {
            case directory, report, translations, tafsirs, mirroredTafsirs, surahInfo
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            directory = try container.decode(String.self, forKey: .directory)
            report = try container.decode(String.self, forKey: .report)
            translations = try container.decodeIfPresent([Translation].self, forKey: .translations) ?? []
            tafsirs = try container.decodeIfPresent([Tafsir].self, forKey: .tafsirs) ?? []
            mirroredTafsirs = try container.decodeIfPresent([MirroredTafsir].self, forKey: .mirroredTafsirs) ?? []
            surahInfo = try container.decodeIfPresent([SurahInfo].self, forKey: .surahInfo) ?? []
        }
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

    /// Where the app target picks the outputs up (T4). The build writes under `QuranData/out/` and
    /// then copies what it wrote here, so the app never reads a half-written file and the outputs
    /// can be checked against what is installed (`InstalledTests`). Whether the copies are
    /// committed is the `.gitignore`'s decision, by file name, not this one's.
    struct Install: Decodable {
        /// The database's destination, relative to the config file.
        let database: String
        /// The folder every pack this profile wrote is copied into. The app's synchronized group
        /// flattens it into the bundle root, which is why the app finds packs by file prefix.
        let packs: String?
        /// The folder the QUL header, surah-name and common faces are copied into (qul only).
        let fonts: String?
    }

    let profile: Profile
    /// The database, relative to the config file.
    let output: String
    let install: Install?
    let tanzil: Tanzil?
    let qul: QUL?
    let packs: Packs?
    let curated: Curated?
    let sizeReport: SizeReportConfig

    /// Folder holding the config file.
    private(set) var base = URL(fileURLWithPath: ".")

    private enum CodingKeys: String, CodingKey {
        case profile, output, install, tanzil, qul, packs, curated, sizeReport
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
        let packInputs = (packs?.translations ?? []).flatMap { [$0.file] + ($0.crossCheck.map { [$0] } ?? []) }
            + (packs?.tafsirs ?? []).map(\.file)
            + (packs?.surahInfo ?? []).map(\.file)
        return ([qul.surahs, qul.ayahs, qul.imlaei, qul.words.hafs, qul.words.glyphV2] + tables
            + qul.styles.map(\.layout) + fontInputs + packInputs).map(input)
    }
}

struct InputFile {
    /// Relative to `QuranData/raw/`, as written in SOURCES.md.
    let relativePath: String
    let url: URL
}
