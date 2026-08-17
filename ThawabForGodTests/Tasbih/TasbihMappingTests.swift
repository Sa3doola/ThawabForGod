//
//  TasbihMappingTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// `TasbihSessionModel` ↔ `TasbihSession`, the boundary between SwiftData and the domain.
///
/// Tested through the model directly rather than through a container: the round-trip is where a
/// dropped field would hide, and it costs nothing to check every one of them.
@MainActor
struct TasbihSessionMappingTests {

    private let session = TasbihSession(
        id: UUID(uuidString: "8B7B4C36-3F5B-4B8E-9C7A-1D2E3F4A5B6C")!,
        dhikrID: "alhamdulillah",
        currentCount: 17,
        targetCount: 33,
        completedLaps: 6,
        lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
    )

    @Test func aSessionSurvivesTheRoundTripWhole() {
        let model = TasbihSessionModel(session)

        #expect(model.domainValue == session)
    }

    @Test func everyFieldReachesTheModel() {
        let model = TasbihSessionModel(session)

        #expect(model.id == session.id)
        #expect(model.dhikrID == "alhamdulillah")
        #expect(model.currentCount == 17)
        #expect(model.targetCount == 33)
        #expect(model.completedLaps == 6)
        #expect(model.lastUpdated == session.lastUpdated)
    }

    /// `apply` is what the repository's upsert uses, so what it deliberately leaves alone matters
    /// as much as what it writes: moving the row's identity or its key on a save would orphan the
    /// user's count.
    @Test func applyingUpdatesTheProgressAndLeavesTheIdentityAlone() {
        let model = TasbihSessionModel(session)
        let originalID = model.id

        var updated = session
        updated.currentCount = 2
        updated.completedLaps = 7
        updated.targetCount = 100
        updated.lastUpdated = Date(timeIntervalSince1970: 1_800_000_000)
        model.apply(updated)

        #expect(model.currentCount == 2)
        #expect(model.completedLaps == 7)
        #expect(model.targetCount == 100)
        #expect(model.lastUpdated == updated.lastUpdated)
        #expect(model.id == originalID)
        #expect(model.dhikrID == "alhamdulillah")
    }
}

/// The corpus side: a GRDB row becomes a `TasbihDhikr`.
///
/// Built from a hand-made record rather than a fetched row — the row-to-record half is covered
/// end to end by `TasbihCatalogRepositoryTests` against the real bundle, and reaching a GRDB `Row`
/// directly would mean linking GRDB into the test target for no gain.
struct TasbihPresetMappingTests {

    private let record = TasbihPresetRecord(
        id: "subhanallah",
        arabicText: "سُبْحَانَ اللَّهِ",
        translationEnglish: "Glory be to Allah",
        targetCount: 33
    )

    @Test func anEnglishReaderGetsTheTranslation() {
        let dhikr = record.domainValue(in: .english)

        #expect(dhikr.id == "subhanallah")
        #expect(dhikr.arabicText == record.arabicText)
        #expect(dhikr.translation == "Glory be to Allah")
        #expect(dhikr.targetCount == 33)
    }

    /// For an Arabic reader the phrase *is* the dhikr, so the row simply omits the line rather
    /// than printing the Arabic twice.
    @Test func anArabicReaderGetsNoTranslation() {
        let dhikr = record.domainValue(in: .arabic)

        #expect(dhikr.arabicText == record.arabicText)
        #expect(dhikr.translation == nil)
    }

    @Test(arguments: [(0, 1), (-3, 1), (1, 1), (33, 33)])
    func anImpossibleTargetIsClamped(stored: Int, expected: Int) {
        let record = TasbihPresetRecord(
            id: "x",
            arabicText: "…",
            translationEnglish: "…",
            targetCount: stored
        )

        #expect(record.domainValue(in: .english).targetCount == expected)
    }
}
