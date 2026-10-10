//
//  JalalaynSilenceTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Tafsir al-Jalalayn passes over 226 ayahs, and for those the answer is `nil` (T16): the screen
/// says this commentary has no note here. Never a neighbour's note — the one failure the old
/// `TafsirViewModel.Phase.silent` existed to prevent, now kept by the repository.
///
/// Run against the public Quran's ayah index and, where it exists, the full one's: the pack is the
/// same file in both builds, and must read the same.
struct JalalaynSilenceTests {

    static let databases = [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : [])

    private func repository(_ database: QuranDatabase) -> TafsirRepository {
        TafsirRepository(store: QuranTestData.bundledPacks, index: QuranTestData.index(database))
    }

    @Test(arguments: databases)
    func theCommentaryIsSilentOnExactly226Ayahs(_ database: QuranDatabase) async throws {
        let repository = repository(database)
        let index = QuranTestData.index(database)

        var silent: [VerseReference] = []
        for id in 1...6236 {
            let ayah = try #require(try index.reference(of: id))
            if try await repository.tafsir(for: ayah, pack: QuranTestData.jalalayn) == nil { silent.append(ayah) }
        }

        #expect(silent.count == 226)
    }

    /// The verses the old tafsir tests named as passed over.
    @Test(arguments: ["2:82", "2:274", "2:277", "3:2", "5:10"])
    func aVerseTheCommentaryPassesOverHasNoNote(_ key: String) async throws {
        let ayah = try #require(VerseReference(parsing: key))

        #expect(try await repository(QuranTestData.preferredDatabase).tafsir(for: ayah, pack: QuranTestData.jalalayn) == nil)
    }

    /// Its neighbours have notes of their own, and each note covers its own ayah alone — no group
    /// in Jalalayn could lend one verse's note to the next.
    @Test func theNeighboursOfASilentVerseKeepTheirOwnNotes() async throws {
        let repository = repository(QuranTestData.preferredDatabase)
        let before = try #require(try await repository.tafsir(for: VerseReference(surah: 2, verse: 81), pack: QuranTestData.jalalayn))
        let after = try #require(try await repository.tafsir(for: VerseReference(surah: 2, verse: 83), pack: QuranTestData.jalalayn))

        #expect(before.range == VerseReference(surah: 2, verse: 81)...VerseReference(surah: 2, verse: 81))
        #expect(after.range == VerseReference(surah: 2, verse: 83)...VerseReference(surah: 2, verse: 83))
        #expect(!before.isGroup && !after.isGroup)
        #expect(before.html != after.html)
    }

    @Test func aVerseWithANoteHasIt() async throws {
        let kursi = VerseReference(surah: 2, verse: 255)
        let entry = try #require(try await repository(QuranTestData.preferredDatabase).tafsir(for: kursi, pack: QuranTestData.jalalayn))

        #expect(entry.ayah == kursi)
        #expect(entry.pack == QuranTestData.jalalayn)
        #expect(entry.html.hasPrefix("<p>"))
    }

    /// Silence and absence are different answers: a pack that is not bundled throws, so the screen
    /// can say "unavailable" rather than "no note here".
    @Test func aPackThatIsNotBundledIsNotSilence() async throws {
        let missing = ContentPackID("ar-not-bundled")

        await #expect(throws: ContentPackError.notInstalled(missing)) {
            try await repository(QuranTestData.preferredDatabase).tafsir(for: VerseReference(surah: 1, verse: 1), pack: missing)
        }
    }
}
