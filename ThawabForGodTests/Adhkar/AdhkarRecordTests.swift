//
//  AdhkarRecordTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The one place a database row becomes the value a screen renders.
///
/// Tested here against hand-built records rather than fetched ones: the row → record half is
/// covered end to end by `AdhkarRepositoryTests` against the real bundle, and reaching a GRDB
/// `Row` directly would mean linking GRDB into the test target for no gain.
struct AdhkarRecordTests {

    // MARK: Chapters

    @Test func aChapterRowBecomesTheValueTheListDraws() throws {
        let record = AdhkarCategoryRecord(
            id: "entering-the-market",
            titleArabic: "دعاء دخول السوق",
            titleEnglish: "Entering the market",
            groupID: "travel",
            sortOrder: 98,
            dhikrCount: 1
        )

        let category = try #require(record.domainValue)

        #expect(category.id == "entering-the-market")
        #expect(category.titleArabic == record.titleArabic)
        #expect(category.titleEnglish == record.titleEnglish)
        #expect(category.group == .travel)
        #expect(category.sortOrder == 98)
        #expect(category.dhikrCount == 1)
    }

    /// A corpus rebuilt with a group this build has no case for drops that chapter rather than
    /// trapping — and rather than filing it under some fallback heading, which would put a
    /// chapter under a heading nobody chose for it.
    @Test func aChapterInAnUnknownGroupIsDropped() {
        let record = AdhkarCategoryRecord(
            id: "somewhere-new",
            titleArabic: "باب",
            titleEnglish: "A chapter",
            groupID: "a-group-from-the-future",
            sortOrder: 1,
            dhikrCount: 1
        )

        #expect(record.domainValue == nil)
    }

    // MARK: Adhkar

    @Test func aDhikrRowBecomesTheValueTheCardDraws() {
        let record = DhikrRecord(id: 1017, arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", repeatCount: 100)
        let dhikr = record.domainValue

        #expect(dhikr.id == 1017)
        #expect(dhikr.arabicText == record.arabicText)
        #expect(dhikr.repeatCount == 100)
    }

    /// A zero would give the reader a counter that can never be completed. The schema forbids it
    /// and the mapper clamps it anyway — the corpus is third-party content nobody has read line
    /// by line, and a belt-and-braces floor here costs nothing.
    @Test func aRepeatCountBelowOneIsClampedRatherThanTrusted() {
        #expect(DhikrRecord(id: 1, arabicText: "ذكر", repeatCount: 0).domainValue.repeatCount == 1)
        #expect(DhikrRecord(id: 2, arabicText: "ذكر", repeatCount: -4).domainValue.repeatCount == 1)
    }
}
