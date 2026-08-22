//
//  Hadith.swift
//  ThawabForGod
//

import Foundation

/// One narration, as the reading screen draws it.
///
/// Arabic and nothing else, which is the shape of the corpus rather than an omission this type
/// is hiding: the two Sahihs are eleven centuries out of copyright, and every English rendering
/// of them belongs to a living translator. `Resources/Corpus/README.md` records the position and
/// what would have to change for a translation to arrive.
///
/// There is also no grading on it, and that is not a field waiting to be filled. A narration
/// from either of these collections is graded by being in it; a grading beside the text would be
/// a modern scholar's judgement, which is both unnecessary here and unlicensed everywhere.
nonisolated struct Hadith: Identifiable, Hashable, Sendable {

    /// Which narration this is, in terms that outlive the file it was read from.
    let id: HadithID

    /// Which kitab it sits in.
    let bookNumber: Int

    /// The number, or span of numbers, this narration is published under.
    let reference: HadithReference

    /// The narration itself, vowelled as the corpus stores it.
    let text: String

    /// Which collection it comes from. On the identity, and read through for convenience.
    var collectionID: String { id.collection }
}

/// Which narration, in terms nothing about the corpus file can change.
///
/// **Not the SQLite rowid**, and the distinction is what this type exists for. The rowid is
/// assigned by `build_hadith_db.py` in the order it happens to insert rows; rebuild the corpus
/// with one narration regrouped and every id after it shifts. That is harmless while a list is on
/// screen and ruinous the moment something is *stored* against it — every bookmark a reader has
/// would quietly come to name a different hadith.
///
/// So the identity is the citation plus the one thing the citation cannot express. `collection`
/// and `number` are how the narration is referred to in print; `part` distinguishes the
/// twenty-six places where Sahih al-Bukhari carries two narrations under one number, and is 0
/// everywhere else. All three are properties of the published collections rather than of this
/// project's file, which is what makes them safe to write down.
nonisolated struct HadithID: Hashable, Sendable {

    /// Which of the two Sahihs — `bukhari` or `muslim`.
    let collection: String

    /// The reference number it is published under, or the first of its span.
    let number: Int

    /// Which narration under that number this is. 0 for all but twenty-six of them.
    let part: Int

    init(collection: String, number: Int, part: Int = 0) {
        self.collection = collection
        self.number = number
        self.part = part
    }
}

/// Where a narration is found, in the form a reader would write it down.
///
/// A *span* rather than a number, because a few hundred of them are published under several
/// consecutive numbers at once — one narration that later editions cite as 5709, 5710, 5711 or
/// 5712 indifferently. Carrying only the first would make three of those four citations
/// unanswerable; carrying the span means a reader who arrives with any of them is in the right
/// place, and the screen can say which numbers this text is the text of.
nonisolated struct HadithReference: Hashable, Sendable {

    /// The collection the numbers belong to. A number means nothing without it.
    let collection: String

    /// The first number the narration is published under, and the one to lead with.
    let first: Int

    /// The last. Equal to `first` for all but a few hundred narrations.
    let last: Int

    init(collection: String, first: Int, last: Int? = nil) {
        self.collection = collection
        self.first = first
        self.last = max(last ?? first, first)
    }

    /// Whether this narration carries more than one number, and the screen has a range to draw.
    var isSpan: Bool { last > first }

    /// Whether `number` is one of the numbers this narration answers to.
    func covers(_ number: Int) -> Bool { (first...last).contains(number) }
}
