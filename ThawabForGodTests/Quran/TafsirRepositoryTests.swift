//
//  TafsirRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The tafsir repository over the bundled packs, with real groups from the QUL commentaries. The
/// public build bundles only Tafsir al-Jalalayn, so the group assertions are guarded on the full
/// data; the rest runs everywhere.
///
/// Silence is `nil` and an unknown pack throws `ContentPackError.notInstalled` (T16): a commentary
/// that passes over an ayah must never print a neighbour's note, and a missing pack must never look
/// like silence. Al-Jalalayn's own silent ayahs are covered by its own suite.
@MainActor
struct TafsirRepositoryTests {
    let muyassar = ContentPackID("ar-muyassar")
    let mukhtasar = ContentPackID("en-mukhtasar")
    let repository = TafsirRepository(store: QuranTestData.bundledPacks, index: QuranTestData.index())

    /// Every bundled tafsir is a tafsir, and the one in every clone is there.
    @Test func installedListsOnlyTafsirs() async {
        let packs = await repository.installed()
        #expect(packs.allSatisfy { $0.kind == .tafsir })
        #expect(packs.contains { $0.id == QuranTestData.jalalayn })
    }

    /// The full build's tafsirs, with the direction each one is drawn in.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func fullBuildListsEveryTafsirWithItsDirection() async throws {
        let packs = await repository.installed()
        #expect(Set(packs.map(\.id)) == [QuranTestData.jalalayn, muyassar, mukhtasar])
        #expect(packs.first { $0.id == muyassar }?.direction == .rtl)
        #expect(packs.first { $0.id == mukhtasar }?.direction == .ltr)
    }

    /// Al-Mukhtasar explains 2:3–4 together: both ayahs get the same text and the range.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func groupedAyahsShareTheOwnersText() async throws {
        let third = try #require(try await repository.tafsir(for: VerseReference(surah: 2, verse: 3), pack: mukhtasar))
        let fourth = try #require(try await repository.tafsir(for: VerseReference(surah: 2, verse: 4), pack: mukhtasar))
        #expect(third.range == VerseReference(surah: 2, verse: 3)...VerseReference(surah: 2, verse: 4))
        #expect(fourth.range == third.range && fourth.html == third.html && fourth.isGroup)
        #expect(fourth.ayah == VerseReference(surah: 2, verse: 4))
        #expect(third.html.hasPrefix("They believe in the revelation"))
        // Its only four-ayah group, asked from the middle.
        let middle = try #require(try await repository.tafsir(for: VerseReference(surah: 37, verse: 169), pack: mukhtasar))
        #expect(middle.range == VerseReference(surah: 37, verse: 167)...VerseReference(surah: 37, verse: 170))
        // The next ayah stands alone.
        let fifth = try #require(try await repository.tafsir(for: VerseReference(surah: 2, verse: 5), pack: mukhtasar))
        #expect(!fifth.isGroup && fifth.range == VerseReference(surah: 2, verse: 5)...VerseReference(surah: 2, verse: 5))
    }

    /// Muyassar: 2:3 alone, 2:45–46 and its largest group, 81:1–14.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func muyassarGroups() async throws {
        let single = try #require(try await repository.tafsir(for: VerseReference(surah: 2, verse: 3), pack: muyassar))
        #expect(!single.isGroup)
        #expect(single.html.hasPrefix(#"<div lang="ar"><p>وهم الذين يُصَدِّقون بالغيب"#))
        let pair = try #require(try await repository.tafsir(for: VerseReference(surah: 2, verse: 46), pack: muyassar))
        #expect(pair.range == VerseReference(surah: 2, verse: 45)...VerseReference(surah: 2, verse: 46))
        let first = try #require(try await repository.tafsir(for: VerseReference(surah: 81, verse: 1), pack: muyassar))
        let seventh = try #require(try await repository.tafsir(for: VerseReference(surah: 81, verse: 7), pack: muyassar))
        #expect(seventh.range == VerseReference(surah: 81, verse: 1)...VerseReference(surah: 81, verse: 14))
        #expect(seventh.html == first.html)
        let after = try #require(try await repository.tafsir(for: VerseReference(surah: 81, verse: 15), pack: muyassar))
        #expect(after.range.lowerBound == VerseReference(surah: 81, verse: 15))
    }

    /// Every ayah of the Quran, in both QUL tafsirs, comes back with text and a range around it.
    /// (Walks the 6,236 global ids through the ayah index, which is the same set the corpus holds.)
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func noAyahIsEverBlank() async throws {
        let index = QuranTestData.index()
        var groups = [muyassar: Set<VerseReference>(), mukhtasar: Set<VerseReference>()]
        for id in 1...6236 {
            let ayah = try #require(try index.reference(of: id))
            for pack in [muyassar, mukhtasar] {
                let entry = try #require(try await repository.tafsir(for: ayah, pack: pack), "\(pack) \(ayah)")
                #expect(!entry.html.isEmpty && entry.range.contains(ayah), "\(pack) \(ayah)")
                #expect(entry.range.lowerBound.surah == entry.range.upperBound.surah, "\(pack) \(ayah)")
                groups[pack]?.insert(entry.range.lowerBound)
            }
        }
        // One range per group. (Texts are not unique: repeated ayahs, such as the refrain of
        // Ar-Rahman, have identical entries in separate groups.)
        #expect(groups[muyassar]?.count == 5040)
        #expect(groups[mukhtasar]?.count == 6216)
    }

    /// The "Tafsir of ayahs 2:3–4" label. Each number goes through the digit format the caller
    /// passes; the app passes `LocalizationManager`'s, and these tests pass the two shapes it can
    /// produce: ASCII, and Arabic-Indic built here.
    @Test func rangeTextFollowsTheDigitFormat() {
        func entry(_ first: VerseReference, _ last: VerseReference) -> TafsirEntry {
            TafsirEntry(pack: QuranTestData.jalalayn, ayah: first, range: first...last, html: "x")
        }
        let latin: (Int) -> String = { String($0) }
        let arabicIndic: (Int) -> String = { number in
            String(String(number).unicodeScalars.map { Character(Unicode.Scalar($0.value + 0x0660 - 0x30)!) })
        }
        let group = entry(VerseReference(surah: 2, verse: 3), VerseReference(surah: 2, verse: 4))
        let lrm = "\u{200E}"
        #expect(group.rangeText(format: latin, isRightToLeft: true) == "2:3–4")
        #expect(group.rangeText(format: arabicIndic, isRightToLeft: true) == "٢:٣–٤")
        // Left-to-right text: marks keep the dash between the two numbers.
        #expect(group.rangeText(format: arabicIndic) == "٢:٣\(lrm)–\(lrm)٤")
        #expect(entry(VerseReference(surah: 2, verse: 255), VerseReference(surah: 2, verse: 255)).rangeText(format: latin) == "2:255")
        #expect(entry(VerseReference(surah: 2, verse: 286), VerseReference(surah: 3, verse: 1)).rangeText(format: latin, isRightToLeft: true) == "2:286–3:1")
    }

    /// A pack that is not bundled, and a translation pack, are not tafsirs: both throw rather than
    /// answer silence.
    @Test func unknownPacksThrow() async {
        let verse = VerseReference(surah: 1, verse: 1)
        await #expect(throws: ContentPackError.notInstalled(ContentPackID("not-bundled"))) {
            try await repository.tafsir(for: verse, pack: ContentPackID("not-bundled"))
        }
        // A translation pack is not a tafsir.
        await #expect(throws: ContentPackError.notInstalled(ContentPackID("en-sahih-international"))) {
            try await repository.tafsir(for: verse, pack: ContentPackID("en-sahih-international"))
        }
    }

    /// With no packs at all, nothing is installed and every pack throws.
    @Test func emptyStoreHasNoTafsirs() async {
        let empty = TafsirRepository(store: ContentPackStore(directory: nil), index: QuranTestData.index())
        #expect(await empty.installed().isEmpty)
        await #expect(throws: ContentPackError.notInstalled(ContentPackID("ar-muyassar"))) {
            try await empty.tafsir(for: VerseReference(surah: 1, verse: 1), pack: ContentPackID("ar-muyassar"))
        }
    }
}
