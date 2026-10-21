//
//  OccasionSourcesTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Holds every Bukhari and Muslim reference in `IslamicEvents.json` to the corpus that ships.
///
/// The Muslim numbers once followed the printed (Abd al-Baqi) numbering while the corpus has its
/// own sequence, so each citation landed on an unrelated narration. The expectations below are the
/// narrator and a marker of the content the virtue text relies on.
struct OccasionSourcesTests {

    private struct Expectation {
        let work: OccasionWork
        let reference: String
        let narrator: String
        let marker: String
    }

    private static let expectations: [Expectation] = [
        .init(work: .sahihMuslim, reference: "2746", narrator: "أَبِي قَتَادَةَ", marker: "عَاشُورَاءَ"),
        .init(work: .sahihMuslim, reference: "2747", narrator: "أَبِي قَتَادَةَ", marker: "الاثْنَيْنِ"),
        .init(work: .sahihMuslim, reference: "2758", narrator: "أَبِي أَيُّوبَ", marker: "سِتًّا مِنْ شَوَّالٍ"),
        .init(work: .sahihMuslim, reference: "2678", narrator: "نُبَيْشَةَ", marker: "وَذِكْرٍ لِلَّهِ"),
        .init(work: .sahihMuslim, reference: "2776", narrator: "عَائِشَةَ", marker: "الْعَشْرِ الأَوَاخِرِ"),
        .init(work: .sahihBukhari, reference: "2017", narrator: "عَائِشَةَ", marker: "الْوِتْرِ"),
        .init(work: .sahihBukhari, reference: "969", narrator: "ابْنِ عَبَّاسٍ", marker: "أَيَّامِ الْعَشْرِ"),
    ]

    /// Vowel marks and tatweel off, so the comparison is about letters and not mark order.
    private static func bare(_ text: String) -> String {
        String(text.unicodeScalars.filter { !(0x064B...0x0652).contains($0.value) && $0.value != 0x0670 && $0.value != 0x0640 }
            .map(Character.init))
    }

    private func collectionID(_ work: OccasionWork) -> String? {
        switch work {
        case .sahihBukhari: "bukhari"
        case .sahihMuslim: "muslim"
        default: nil
        }
    }

    @Test func everyCitedNarrationIsInTheCorpusAndMatchesItsVirtueText() async throws {
        let repository = HadithRepository(database: CorpusDatabase(name: "hadith"))
        for expectation in Self.expectations {
            let id = HadithID(collection: try #require(collectionID(expectation.work)), number: try #require(Int(expectation.reference)))
            let narration = try #require(try await repository.hadiths([id]).first, "\(expectation.reference) missing")
            let text = Self.bare(narration.text)
            #expect(text.contains(Self.bare(expectation.narrator)), "\(expectation.reference): narrator")
            #expect(text.contains(Self.bare(expectation.marker)), "\(expectation.reference): content")
        }
    }

    @Test func everySahihSourceInTheCatalogIsCoveredByAnExpectation() {
        let covered = Set(Self.expectations.map { "\($0.work.rawValue)/\($0.reference)" })
        for occasion in BundledOccasionsRepository().occasions() {
            for source in occasion.sources where collectionID(source.work) != nil {
                #expect(covered.contains("\(source.work.rawValue)/\(source.reference)"), "\(occasion.id)")
            }
        }
    }
}
