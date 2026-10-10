// Usage, from the repository root:
//
//   swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile tanzil
//   swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile qul
//
// `--profile <name>` reads `Tools/QuranBuilder/profiles/<name>.json`; `--config <path>` reads any
// other. Every output — the database, `Packs/` and the pack report — is written under
// `QuranData/out/<profile>/` (git-ignored); the qul profile also fills `QuranData/Fonts/madaniV2/`
// with the page fonts. Once every check has passed, the profile's `install` section copies the
// database, the packs and (qul) the QUL faces into the app's resources: tanzil's copies are
// committed, qul's are git-ignored by name (QURAN_MIGRATION_PLAN.md, T4).

import Foundation
import QuranDataModel

/// `Tools/QuranBuilder`, found from this file rather than the working directory, so the command
/// works from the repository root and from the package folder alike.
let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

func configPath() throws -> String {
    let args = CommandLine.arguments
    if let index = args.firstIndex(of: "--config"), index + 1 < args.count { return args[index + 1] }
    if let index = args.firstIndex(of: "--profile"), index + 1 < args.count {
        return packageRoot.appendingPathComponent("profiles/\(args[index + 1]).json").path
    }
    throw BuildError.usage
}

func build() async throws {
    let config = try BuildConfig.load(path: try configPath())
    print("profile \(config.profile.rawValue)")

    let rows: QuranCorpusRows
    // QUL inputs verified against SOURCES.md, by path; the fonts are copied against these.
    var verified: [String: String] = [:]
    switch config.profile {
    case .tanzil:
        let tanzil = config.tanzil!
        rows = try await TanzilCorpus.load(config)
            .rows(textDigest: tanzil.text.verseDigest, searchDigest: tanzil.searchText.verseDigest)
    case .qul:
        let corpus = try QULCorpus.load(config)
        verified = corpus.inputHashes
        rows = try corpus.rows()
    }

    let output = config.path(config.output)
    let summary = try QuranSQLiteWriter(profile: config.profile).write(rows, to: output)
    print("\(output.lastPathComponent): ayahs \(summary.ayahs), words \(summary.words) + markers \(summary.markers), pages \(summary.pagesByStyle), capabilities \(rows.capabilities.map(\.rawValue))")
    print("wrote \(output.path) (\(summary.bytes / 1024) KB)")

    if config.profile == .qul {
        let qul = config.qul!
        for font in try copyBundledFonts(config, verified: verified) {
            print("font \(font.name) (\(font.bytes / 1024) KB) verified and copied to \(qul.fonts.bundleDirectory)")
        }
        for pageFonts in qul.pageFonts {
            let copied = try copyPageFonts(pageFonts, config: config)
            print("\(pageFonts.style) page fonts: \(copied.files) files (\(copied.bytes / 1_048_576) MB) verified and copied to \(pageFonts.bundleDirectory)")
        }
    }

    // Packs, joined to the ayahs by "surah:ayah" and never by order.
    for pack in try await buildPacks(config, ayahIDs: rows.ayahIDs).packs {
        print("pack \(pack.file): \(pack.kind) \(pack.language) \(pack.nameEn), \(pack.bytes / 1024) KB, sha256 \(pack.sha256.prefix(12))…")
    }

    if let curated = config.curated {
        let list = try buildAyahOfTheDay(curated, config: config, ayahCounts: rows.ayahCounts)
        print("ayah of the day: \(list.entries.count) entries (\(list.status)), sha256 \(list.sha256.prefix(12))… → \(curated.ayahOfTheDayOutput)")
    }

    // Everything above will ship in the download; fail if it outgrows the budget.
    let budget = config.sizeReport
    let report = try SizeReport(folders: budget.paths.map(config.path))
    print("size report (\(config.profile.rawValue)):")
    for line in report.lines(budgetCompressedMB: budget.budgetCompressedMB, budgetInstalledMB: budget.budgetInstalledMB) {
        print("  " + line)
    }
    let violations = report.violations(budgetCompressedMB: budget.budgetCompressedMB, budgetInstalledMB: budget.budgetInstalledMB)
    try require(violations.isEmpty, violations.joined(separator: "; "))

    for file in try installOutputs(config) {
        print("installed \(file.path)")
    }
}

do {
    try await build()
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
