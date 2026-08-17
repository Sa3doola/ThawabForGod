//
//  DhikrRecordTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The one place the two-language database row becomes the one-language value a screen renders.
///
/// Tested here against a hand-built record rather than a fetched one: the row → record half is
/// covered end to end by `AdhkarRepositoryTests` against the real bundle, and reaching a GRDB
/// `Row` directly would mean linking GRDB into the test target for no gain.
struct DhikrRecordTests {

    private let record = DhikrRecord(
        id: 12,
        arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
        translationEnglish: "Glory is to Allah and praise is to Him.",
        transliterationEnglish: "Subḥāna-llāhi wa biḥamdih.",
        referenceArabic: "مسلم، برقم 2692.",
        referenceEnglish: "Muslim 2692.",
        virtueArabic: "من قالها حُطَّت خطاياه.",
        virtueEnglish: "Whoever says it has his sins forgiven.",
        repeatCount: 100
    )

    @Test func anEnglishReaderGetsTheEnglishColumns() {
        let dhikr = record.domainValue(in: .english)

        #expect(dhikr.id == 12)
        #expect(dhikr.arabicText == record.arabicText)
        #expect(dhikr.translation == record.translationEnglish)
        #expect(dhikr.transliteration == record.transliterationEnglish)
        #expect(dhikr.reference == record.referenceEnglish)
        #expect(dhikr.virtue == record.virtueEnglish)
        #expect(dhikr.repeatCount == 100)
    }

    @Test func anArabicReaderGetsTheArabicColumnsAndNoTranslation() {
        let dhikr = record.domainValue(in: .arabic)

        #expect(dhikr.arabicText == record.arabicText)
        #expect(dhikr.translation == nil)
        #expect(dhikr.transliteration == nil)
        #expect(dhikr.reference == record.referenceArabic)
        #expect(dhikr.virtue == record.virtueArabic)
    }

    /// The corpus is third-party content nobody has verified line by line yet. A zero would give
    /// the reader a counter that can never be completed, so it is clamped rather than trusted.
    @Test(arguments: [(0, 1), (-4, 1), (1, 1), (7, 7)])
    func anImpossibleRepeatCountIsClampedToOne(stored: Int, expected: Int) {
        let record = DhikrRecord(
            id: 1,
            arabicText: "…",
            translationEnglish: "…",
            transliterationEnglish: nil,
            referenceArabic: "…",
            referenceEnglish: "…",
            virtueArabic: nil,
            virtueEnglish: nil,
            repeatCount: stored
        )

        #expect(record.domainValue(in: .english).repeatCount == expected)
    }

    /// An absent virtue or transliteration stays absent — the card hides the block rather than
    /// drawing an empty heading.
    @Test func absentFieldsStayAbsent() {
        let record = DhikrRecord(
            id: 2,
            arabicText: "…",
            translationEnglish: "…",
            transliterationEnglish: nil,
            referenceArabic: "…",
            referenceEnglish: "…",
            virtueArabic: nil,
            virtueEnglish: nil,
            repeatCount: 1
        )

        #expect(record.domainValue(in: .english).virtue == nil)
        #expect(record.domainValue(in: .english).transliteration == nil)
        #expect(record.domainValue(in: .arabic).virtue == nil)
    }
}
