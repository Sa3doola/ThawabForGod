// Shared paths and the layout facts the integrity tests check the built databases against.
// Run, after building the profiles you have inputs for:
//
//   swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile tanzil
//   swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile qul   # needs QuranData/raw
//   swift test --package-path Tools/QuranBuilder
//
// Suites that read a profile's output are skipped, with the reason, when that output has not been
// built — a public clone has no QUL downloads and builds only `tanzil`.

import CryptoKit
import Foundation

enum Paths {
    /// Repository root: …/Tools/QuranBuilder/Tests/QuranDataIntegrityTests/<file>.
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    static let quranData = root.appendingPathComponent("QuranData")
    static let raw = quranData.appendingPathComponent("raw")
    static let sources = quranData.appendingPathComponent("SOURCES.md")
    static let out = quranData.appendingPathComponent("out")

    // MARK: qul

    /// The full database (`--profile qul`).
    static let quranSQLite = out.appendingPathComponent("qul/quran-mushaf.sqlite")
    /// The QUL header, surah-name and juz-name fonts the qul profile copies out.
    static let bundledFonts = out.appendingPathComponent("qul/Fonts")
    /// The 604 V2 page fonts: the folder the app target references.
    static let pageFonts = quranData.appendingPathComponent("Fonts/madaniV2")

    // MARK: tanzil

    /// The public database (`--profile tanzil`).
    static let tanzilSQLite = out.appendingPathComponent("tanzil/quran.sqlite")

    // MARK: Packs

    /// A profile's pack folder: the files the app will discover by prefix.
    static func packs(_ profile: String) -> URL { out.appendingPathComponent("\(profile)/Packs") }
    /// What the build wrote, with sizes and hashes. A report, never bundled.
    static func packReport(_ profile: String) -> URL { out.appendingPathComponent("reports/\(profile)-packs.json") }
    static var jalalaynBuilt: Bool {
        FileManager.default.fileExists(atPath: packs("tanzil").appendingPathComponent("tafsir-ar-jalalayn.sqlite").path)
    }

    // MARK: Installed in the app

    /// Where the builder installs what it built: the app target's resources (T4). The tanzil
    /// database and its pack are committed; the qul ones are git-ignored by name.
    static let installedCorpus = root.appendingPathComponent("ThawabForGod/Resources/Corpus")
    static let installedQuranSQLite = installedCorpus.appendingPathComponent("quran.sqlite")
    static let installedMushafSQLite = installedCorpus.appendingPathComponent("quran-mushaf.sqlite")
    static let installedPacks = installedCorpus.appendingPathComponent("Packs")
    static let installedQuranFonts = root.appendingPathComponent("ThawabForGod/Resources/Fonts/Quran")

    // MARK: Shared

    /// The KFGQPC Hafs face the app bundles today.
    static let kfgqpcFont = root.appendingPathComponent("ThawabForGod/Resources/Fonts/Quran/KFGQPC-HafsUthmanic.ttf")
    /// The hand-kept ayah-of-the-day list, and the JSON each profile writes from it.
    static let curatedList = root.appendingPathComponent("Tools/QuranBuilder/data/ayah-of-the-day.txt")
    static func curatedJSON(_ profile: String) -> URL { out.appendingPathComponent("\(profile)/ayah-of-the-day.json") }

    // MARK: What has been built

    static var qulBuilt: Bool { FileManager.default.fileExists(atPath: quranSQLite.path) }
    static var tanzilBuilt: Bool { FileManager.default.fileExists(atPath: tanzilSQLite.path) }
    static var rawPresent: Bool { FileManager.default.fileExists(atPath: raw.appendingPathComponent("layout").path) }
}

/// Pages whose line count differs from 15 in the QUL KFGQPC V2 layout. In the printed
/// Madinah Mushaf both opening pages (Al-Fatihah, start of Al-Baqarah) are decorated
/// 8-line pages. Reported as found; the data is the source of truth.
let expectedShortPages: [Int: Int] = [1: 8, 2: 8]

/// Pages whose last line is a surah header; the basmala opens the next page. This is
/// how the 1421H print lays these surahs out.
let expectedHeaderAtPageBottom: Set<Int> = [
    76, 207, 331, 341, 349, 366, 376, 414, 417, 445, 452, 498, 506, 525, 548, 555, 557, 584,
]

/// First page of each juz, Madinah Mushaf (index 0 = juz 1).
let expectedJuzFirstPages = [
    1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282,
    302, 322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
]

/// Surahs whose surah-name-v2 ligature string does not shape to a single glyph. The font's
/// rule for Al-Ahzab matches "033" instead of "surah033": "surah" shapes as five empty,
/// zero-advance glyphs and the name still draws correctly. Reported, not patched.
let expectedMultiGlyphSurahNames: [Int] = [33]

/// The corpus the app shipped before the migration — `quran.sqlite` and `tafsir.sqlite` as
/// `build_quran_db.py` and `build_tafsir_db.py` wrote them — as `Fingerprint`s of the line formats
/// the tests below build. Taken from those files on 2026-10-10, just before M3 replaced the one and
/// deleted the other; the M2 suites had already compared them with this build row for row.
enum PreMigrationCorpus {
    /// `s:v<TAB>text`, the 6,236 verses in order.
    static let text = "ab0242de736a16e11d44df50b5737863b89956af5a41b556586d1bdd07f624cd"
    /// `s:v<TAB>juz<TAB>hizb<TAB>rub<TAB>sajdah`, sajdah in QUL's words or empty.
    static let divisions = "ef150a2942e7d039a9cabae750a317565647e927f882d7a1899d16c06a183ab3"
    /// `s:v<TAB>folded search text`.
    static let searchFold = "6c02d92f0e9844961496b45a703dd6808df308206d75cecf68fa730a3c9358fc"
    /// `word<TAB>s:v,s:v,…` for the 368 probe words of `theSameQueriesFindTheSameVerses`.
    static let searchResults = "e364d408e6a3b8774f4d367931db14e10dcfce43553f6ddbe82bbd949d2f1cdc"
    /// `s:v<TAB>note`, Tafsir al-Jalalayn's 6,010 notes in order.
    static let jalalaynNotes = "39798a890fadc61fcd13c58cae5f7d4ac0ef288ad862c6055576a0c00979cf2c"
}

/// A one-line summary of many rows: the SHA-256 of the lines joined by newlines. What the M3 swap
/// pinned the pre-migration corpus with, so a later build can still be held to it after the files
/// it came from were deleted.
enum Fingerprint {
    static func of(_ lines: [String]) -> String {
        SHA256.hash(data: Data(lines.joined(separator: "\n").utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
