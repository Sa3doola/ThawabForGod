//
//  TranslationRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import SQLite3
import Testing
@testable import ThawabForGod

/// The bundled translation packs and the translation repository over them. Saheeh International is
/// a QUL pack, so the assertions about its text, footnotes and counts are guarded on the full data.
/// The fixture tests build their own pack in a temporary folder, so they run in every build.
///
/// Packs are found by file prefix and describe themselves in their own `pack` table (T15): what
/// matters is that the store finds each pack with the right kind, language, names and direction.
@MainActor
struct TranslationRepositoryTests {
    let saheeh = ContentPackID("en-sahih-international")
    let repository = TranslationRepository(store: QuranTestData.bundledPacks, index: QuranTestData.index())

    // MARK: Bundled packs

    /// The translation list never carries a tafsir, and the store does find the tafsirs.
    @Test func installedListsOnlyTranslations() async {
        let packs = await repository.installed()
        #expect(packs.allSatisfy { $0.kind == .translation })
        #expect(!packs.contains { $0.id == QuranTestData.jalalayn })
        let all = await QuranTestData.bundledPacks.installed()
        #expect(all.contains { $0.id == QuranTestData.jalalayn && $0.kind == .tafsir })
    }

    /// The full build finds Saheeh with its own kind, language, names, direction and licence, and
    /// the other packs by the same prefix rule.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func bundledStoreFindsSaheeh() async throws {
        let all = await QuranTestData.bundledPacks.installed()
        #expect(Set(all.map(\.id)) == [
            saheeh, ContentPackID("ar-muyassar"), ContentPackID("en-mukhtasar"),
            ContentPackID("surah-info-en"), QuranTestData.jalalayn,
        ])
        let packs = await repository.installed()
        #expect(packs.map(\.id) == [saheeh])
        let pack = try #require(packs.first)
        #expect(pack.kind == .translation && pack.language == "en" && pack.direction == .ltr)
        #expect(pack.name(in: .english) == "Saheeh International")
        #expect(pack.license.hasPrefix("unconfirmed"))
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func oneAyahAcrossPacks() async throws {
        let result = try await repository.text(
            for: VerseReference(surah: 2, verse: 255), packs: [saheeh, ContentPackID("not-bundled")]
        )
        #expect(result.count == 1)
        let text = try #require(result.first)
        #expect(text.ayah == VerseReference(surah: 2, verse: 255))
        #expect(text.text.hasPrefix("Allāh - there is no deity except Him, the Ever-Living,[[fn:226497]]"))
        #expect(text.footnotes.count == 6)
        #expect(text.footnotes["226500"]?.isEmpty == false)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func wholeSurahInOneQuery() async throws {
        let fatihah = try await repository.texts(surah: 1, pack: saheeh)
        #expect(fatihah.count == 7)
        #expect(fatihah[VerseReference(surah: 1, verse: 1)]?.text.hasPrefix("In the name of Allāh,") == true)
        let baqarah = try await repository.texts(surah: 2, pack: saheeh)
        #expect(baqarah.count == 286)
        #expect(Set(baqarah.keys) == Set((1...286).map { VerseReference(surah: 2, verse: $0) }))
    }

    /// Asking for a pack that is not bundled throws, in every build.
    @Test func wholeSurahFromAnUnknownPackThrows() async {
        await #expect(throws: ContentPackError.notInstalled(ContentPackID("nope"))) {
            try await repository.texts(surah: 1, pack: ContentPackID("nope"))
        }
    }

    // MARK: Fixture pack

    /// A folder holding one pack built here: a `pack` table describing it, and a `translation` table
    /// with two ayahs, 1:1 (global id 1) and 114:6 (global id 6236). `file` and `kind` can be made to
    /// disagree, which is how the discovery tests build a pack the store must refuse.
    static func fixture(file: String = "translation-xx-test.sqlite", kind: String = "translation") throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("packs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open(folder.appendingPathComponent(file).path, &db) == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
        let sql = """
            CREATE TABLE pack (id TEXT, kind TEXT, language TEXT, name TEXT, name_ar TEXT, author TEXT, author_ar TEXT, direction TEXT, version INT, source_url TEXT, license TEXT);
            CREATE TABLE translation (ayah_id INT PRIMARY KEY, text TEXT, footnotes_json TEXT NULL);
            INSERT INTO pack VALUES ('xx-test', '\(kind)', 'xx', 'Test', 'اختبار', 'Tester', 'مختبر', 'rtl', 1, '', 'test');
            INSERT INTO translation VALUES (1, 'First[[fn:a]] ayah', '{"a":"note a"}');
            INSERT INTO translation VALUES (6236, 'Last ayah', NULL);
            """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
        return folder
    }

    @Test func fixturePackJoinsBySurahAndAyah() async throws {
        let folder = try Self.fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ContentPackStore(directory: folder)
        let packs = await store.installed()
        #expect(packs.map(\.id) == [ContentPackID("xx-test")])
        #expect(packs.first?.direction == .rtl)
        #expect(packs.first?.name(in: .english) == "Test")
        #expect(packs.first?.name(in: .arabic) == "اختبار")

        let repository = TranslationRepository(store: store, index: QuranTestData.index())
        let first = try await repository.text(for: VerseReference(surah: 1, verse: 1), packs: [ContentPackID("xx-test")])
        #expect(first == [TranslationText(
            pack: ContentPackID("xx-test"), ayah: VerseReference(surah: 1, verse: 1),
            text: "First[[fn:a]] ayah", footnotes: ["a": "note a"]
        )])
        let last = try await repository.texts(surah: 114, pack: ContentPackID("xx-test"))
        #expect(last.keys.map(\.verse) == [6])
        #expect(last.values.first?.footnotes.isEmpty == true)
        #expect(try await repository.text(for: VerseReference(surah: 2, verse: 1), packs: [ContentPackID("xx-test")]).isEmpty)
    }

    /// A pack whose file name says one kind and whose `pack` row says another is refused, and so is
    /// a file that is not a database at all, a folder that does not exist, and no folder.
    ///
    /// (Mushaf also refused a pack whose size disagreed with a manifest. The manifest is gone, so
    /// that check has no equivalent: a damaged file is caught by being unreadable instead.)
    @Test func damagedOrMissingPacksAreNotInstalled() async throws {
        let wrongKind = try Self.fixture(kind: "tafsir")
        defer { try? FileManager.default.removeItem(at: wrongKind) }
        #expect(await ContentPackStore(directory: wrongKind).installed().isEmpty)

        let damaged = FileManager.default.temporaryDirectory.appendingPathComponent("damaged-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: damaged, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: damaged) }
        try Data("not a database".utf8).write(to: damaged.appendingPathComponent("translation-xx-test.sqlite"))
        #expect(await ContentPackStore(directory: damaged).installed().isEmpty)

        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("no-packs-\(UUID().uuidString)")
        #expect(await ContentPackStore(directory: missing).installed().isEmpty)
        #expect(await ContentPackStore(directory: nil).url(for: ContentPackID("en-sahih-international")) == nil)
    }
}
