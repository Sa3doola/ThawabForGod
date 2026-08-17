//
//  TasbihCatalogRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Reads the corpus that actually ships.
///
/// The same reasoning as `AdhkarRepositoryTests`: everything above this is tested against stubs
/// and would go on passing if the `tasbih_preset` table were dropped, renamed or rebuilt with a
/// column missing. It also exercises `TasbihPresetRecord.init(row:)`, which nothing else can
/// reach without linking GRDB into the test target.
struct TasbihCatalogRepositoryTests {

    private let repository = TasbihCatalogRepository(database: CorpusDatabase(name: "corpus"))

    @Test func theBundledCorpusHoldsThePresetsInOrder() async throws {
        let presets = try await repository.presets(in: .english)

        #expect(
            presets.map(\.id) == [
                "subhanallah",
                "alhamdulillah",
                "allahuakbar",
                "lailahaillallah",
                "astaghfirullah"
            ]
        )
    }

    /// The three that follow an obligatory prayer sum to a hundred. If a rebuild ever broke that,
    /// the app would quietly be teaching the wrong tasbih.
    @Test func thePostPrayerTargetsAreThirtyThreeThirtyThreeAndThirtyFour() async throws {
        let presets = try await repository.presets(in: .english)
        let targets = Dictionary(
            uniqueKeysWithValues: presets.map { ($0.id, $0.targetCount) }
        )

        #expect(targets["subhanallah"] == 33)
        #expect(targets["alhamdulillah"] == 33)
        #expect(targets["allahuakbar"] == 34)
    }

    @Test(arguments: AppLanguage.allCases)
    func everyPresetHasTextAndAUsableTarget(language: AppLanguage) async throws {
        let presets = try await repository.presets(in: language)

        #expect(!presets.isEmpty)

        for preset in presets {
            #expect(!preset.id.isEmpty)
            #expect(!preset.arabicText.isEmpty, "\(preset.id) has no text")
            #expect(preset.targetCount >= 1, "\(preset.id) asks for \(preset.targetCount)")
        }
    }

    @Test func anEnglishReaderGetsTranslationsAndAnArabicOneDoesNot() async throws {
        let english = try await repository.presets(in: .english)
        let arabic = try await repository.presets(in: .arabic)

        #expect(english.allSatisfy { $0.translation?.isEmpty == false })
        #expect(arabic.allSatisfy { $0.translation == nil })
        #expect(english.map(\.arabicText) == arabic.map(\.arabicText))
    }

    @Test func aMissingCorpusThrowsRatherThanCrashing() async {
        let repository = TasbihCatalogRepository(
            database: CorpusDatabase(name: "not-a-real-corpus")
        )

        await #expect(throws: CorpusDatabaseError.resourceMissing(name: "not-a-real-corpus.sqlite")) {
            try await repository.presets(in: .english)
        }
    }
}
