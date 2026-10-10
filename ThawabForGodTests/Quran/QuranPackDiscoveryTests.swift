//
//  QuranPackDiscoveryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The packs are found by file prefix and described by their own `pack` table (T15) — so a public
/// clone, which bundles Tafsir al-Jalalayn alone, sees exactly that, and a damaged or misnamed
/// file costs that pack rather than the list.
struct QuranPackDiscoveryTests {

    /// What a public clone bundles: one tafsir, no translation, no surah info.
    @Test func theFallbackFindsJalalaynAlone() async throws {
        let folder = try QuranTestData.packFolder(holding: ["tafsir-ar-jalalayn.sqlite"])
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ContentPackStore(directory: folder)

        let packs = await store.installed()
        let jalalayn = try #require(packs.first)

        #expect(packs.count == 1)
        #expect(jalalayn.id == QuranTestData.jalalayn)
        #expect(jalalayn.kind == .tafsir)
        #expect(jalalayn.language == "ar")
        #expect(jalalayn.direction == .rtl)
        #expect(jalalayn.name(in: .arabic) == "تفسير الجلالين")
        #expect(jalalayn.name(in: .english) == "Tafsir al-Jalalayn")
        #expect(jalalayn.license.contains("Public domain"))
        #expect(await store.url(for: QuranTestData.jalalayn) == folder.appendingPathComponent("tafsir-ar-jalalayn.sqlite"))

        let index = QuranTestData.index(QuranTestData.publicDatabase)
        #expect(await TranslationRepository(store: store, index: index).installed().isEmpty)
        #expect(await SurahInfoRepository(store: store).installed().isEmpty)
        #expect(await TafsirRepository(store: store, index: index).installed().map(\.id) == [QuranTestData.jalalayn])
    }

    /// The app bundle itself: Jalalayn always, the four QUL packs where the full data was built.
    @Test func theBundleHoldsJalalaynAndTheQULPacksWhenBuilt() async {
        let ids = Set(await QuranTestData.bundledPacks.installed().map(\.id.rawValue))

        #expect(ids.contains("ar-jalalayn"))
        if QuranTestData.hasFullData {
            #expect(ids == ["ar-jalalayn", "en-sahih-international", "ar-muyassar", "en-mukhtasar", "surah-info-en"])
        } else {
            #expect(ids == ["ar-jalalayn"])
        }
    }

    /// The Quran databases and every other sqlite in the bundle root sit beside the packs; only the
    /// three prefixes are packs.
    @Test func filesWithoutAPackPrefixAreNotPacks() async throws {
        let folder = try QuranTestData.packFolder(holding: ["tafsir-ar-jalalayn.sqlite", "quran.sqlite", "corpus.sqlite"])
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(await ContentPackStore(directory: folder).installed().map(\.id) == [QuranTestData.jalalayn])
    }

    /// A file whose name says one kind and whose `pack` row says another is left out, and so is one
    /// that is not a database at all.
    @Test func aMisnamedOrDamagedPackIsLeftOut() async throws {
        let folder = try QuranTestData.packFolder(holding: ["tafsir-ar-jalalayn.sqlite"])
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.copyItem(
            at: folder.appendingPathComponent("tafsir-ar-jalalayn.sqlite"),
            to: folder.appendingPathComponent("translation-not-really.sqlite")
        )
        try Data("not a database".utf8).write(to: folder.appendingPathComponent("tafsir-damaged.sqlite"))

        #expect(await ContentPackStore(directory: folder).installed().map(\.id) == [QuranTestData.jalalayn])
    }

    @Test func noFolderMeansNoPacks() async {
        #expect(await ContentPackStore(directory: nil).installed().isEmpty)
    }
}
