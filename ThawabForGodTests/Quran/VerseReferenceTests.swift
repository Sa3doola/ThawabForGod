//
//  VerseReferenceTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// A verse's address: its order, its stored form and what a reader may type for it. The stored
/// form is the one worth pinning hardest — `RecentActivity` subjects written by earlier builds are
/// in it, and Mushaf's `AyahID` used the same one, which is what lets the port keep the name.
struct VerseReferenceTests {

    @Test func chapterOutranksVerseInReadingOrder() {
        #expect(VerseReference(surah: 2, verse: 1) > VerseReference(surah: 1, verse: 7))
        #expect(VerseReference(surah: 2, verse: 1) < VerseReference(surah: 2, verse: 2))
        #expect(VerseReference(surah: 2, verse: 286) < VerseReference(surah: 3, verse: 1))
    }

    @Test func itDescribesItselfAsAReference() {
        #expect(VerseReference(surah: 2, verse: 255).description == "2:255")
    }

    /// Whatever keyboard the reader has, and whichever separator they reach for.
    @Test(arguments: ["2:255", "٢:٢٥٥", "۲:۲۵۵", "2/255", " 2:255 ", "2 255"])
    func aTypedReferenceParses(_ text: String) {
        #expect(VerseReference(parsing: text) == VerseReference(surah: 2, verse: 255))
    }

    @Test(arguments: ["", "2", "2:", ":255", "2:255:1", "a:b", "2:٢x", "-2:5"])
    func anythingElseDoesNot(_ text: String) {
        #expect(VerseReference(parsing: text) == nil)
    }

    /// The description is a storage format: what it writes, parsing reads back.
    @Test func theStoredFormRoundTrips() {
        let reference = VerseReference(surah: 114, verse: 6)
        #expect(VerseReference(parsing: reference.description) == reference)
    }

    /// A row written before the move still opens the verse it named, through the same route.
    @Test func anActivityRowStillRoutesToItsVerse() {
        let reference = VerseReference(surah: 18, verse: 10)
        let activity = RecentActivity.quran(reference, of: 110, at: Date())

        #expect(activity.subject == "18:10")
        #expect(activity.route == .quranVerse(reference))
    }
}
