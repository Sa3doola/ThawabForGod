//
//  ContentPackStore.swift
//  ThawabForGod
//

import Foundation
import GRDB
import OSLog

/// `ContentPackStoring` over the packs in the app bundle, found by file prefix (T15).
///
/// Mushaf read a bundled `Packs/manifest.json`. Here the two builds bundle different sets of packs
/// — Jalalayn alone in a public clone, four more where the QUL data was built — and one manifest
/// written by both would dirty git on every local full build. Each pack already describes itself
/// in its own `pack` table, in both languages, so the store reads that. The app target's
/// synchronized group flattens `Resources/Corpus/Packs/` into the bundle root, which is why the
/// prefix is the whole of the discovery: `translation-`, `tafsir-`, `surah-info-`.
///
/// An actor so the scan — a directory listing and a read of each pack's one-row table — runs once,
/// off the main actor, on first use.
actor ContentPackStore: ContentPackStoring {
    private struct Found {
        let pack: ContentPack
        let url: URL
    }

    private let directory: URL?
    private var found: [Found]?

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ThawabForGod", category: "QuranPacks"
    )

    /// - Parameter directory: where the packs are; the bundle's resources by default, a fixture
    ///   folder in tests.
    init(directory: URL? = Bundle.main.resourceURL) {
        self.directory = directory
    }

    func installed() async -> [ContentPack] {
        discover().map(\.pack)
    }

    func url(for pack: ContentPackID) async -> URL? {
        discover().first { $0.pack.id == pack }?.url
    }

    private func discover() -> [Found] {
        if let found { return found }
        let result = Self.scan(directory)
        found = result
        return result
    }

    /// Every pack-named sqlite in `directory` that opens and describes itself as the kind its name
    /// says. A file that does not is left out and logged: a damaged pack must cost the reader that
    /// pack, not the screen.
    private static func scan(_ directory: URL?) -> [Found] {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return [] }

        var found: [Found] = []
        for kind in ContentPackKind.allCases {
            for file in files.filter({ $0.hasPrefix(kind.filePrefix) && $0.hasSuffix(".sqlite") }).sorted() {
                let url = directory.appendingPathComponent(file)
                do {
                    let pack = try readPack(at: url, file: file)
                    guard pack.kind == kind else {
                        logger.error("Pack \(file, privacy: .public) says it is a \(pack.kind.rawValue, privacy: .public)")
                        continue
                    }
                    found.append(Found(pack: pack, url: url))
                } catch {
                    logger.error("Pack \(file, privacy: .public) is unreadable: \(String(describing: error), privacy: .public)")
                }
            }
        }
        return found
    }

    private static func readPack(at url: URL, file: String) throws -> ContentPack {
        let row = try CorpusDatabase(url: url).reader().read { db in
            try Row.fetchOne(db, sql: """
                SELECT id, kind, language, name, name_ar, author, author_ar, direction, version, license FROM pack
                """)
        }
        guard let row,
              let kind = ContentPackKind(rawValue: row[1]),
              let direction = TextDirection(rawValue: row[7])
        else { throw QuranDataError.invalidRow("\(file): no readable pack row") }
        return ContentPack(
            id: ContentPackID(row[0] as String),
            kind: kind,
            language: row[2],
            names: LocalizedPackText(en: row[3], ar: row[4]),
            authors: LocalizedPackText(en: row[5], ar: row[6]),
            direction: direction,
            version: row[8],
            file: file,
            license: row[9]
        )
    }
}
