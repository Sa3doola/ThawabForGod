//
//  AdhkarCategory.swift
//  ThawabForGod
//

import Foundation

/// One chapter of Hisn al-Muslim, and the unit the reading screen works through.
///
/// **It used to be an enum of two cases and is now a value read from the corpus**, because the
/// bundled data grew from the 34 morning-and-evening adhkar of one small upstream to the whole
/// book: 132 chapters, 267 adhkar. An enum of 132 cases would be 132 hand-written places to keep
/// in step with a file, and the compiler could check none of them.
///
/// So which chapters exist is data, and this is what one row of it looks like. The consequence
/// worth naming: **nothing outside the corpus may hold an `AdhkarCategory` value and expect it to
/// still exist.** What crosses that line is the `id` — a slug — and it is stable by construction:
/// `Tools/CorpusBuilder/data/adhkar_categories.json` assigns it, and it is deliberately *not* the
/// chapter number, which is positional and would come to name a different chapter the day the
/// book's order is corrected. That is the same argument `HadithID` makes.
///
/// Both titles are carried rather than one resolved at fetch time, so a language change is a
/// redraw rather than a re-fetch. The Arabic is the book's own chapter title; the English is
/// **this project's rendering of it** and is not verified — see `Resources/Corpus/README.md`.
nonisolated struct AdhkarCategory: Identifiable, Hashable, Sendable {

    /// The stable slug — `"morning-evening"`, `"entering-the-market"`. Safe to put in a deep
    /// link, an activity record or a bookmark.
    let id: String

    /// The chapter title as Hisn al-Muslim writes it.
    let titleArabic: String

    /// The chapter title in English, rendered by this project. Unverified.
    let titleEnglish: String

    let group: AdhkarGroup

    /// The chapter's number in the book, which is the order the list draws them in. Kept even
    /// though the group is what the list is cut on: the sequence is the book's, and losing it
    /// would leave the chapters inside a group in an order nothing chose.
    let sortOrder: Int

    /// How many adhkar are in it. Counted by the query rather than stored on the row, so it
    /// cannot disagree with what the reading screen will actually show.
    let dhikrCount: Int

    /// The title in one language.
    ///
    /// A method rather than two properties read at the call site, so a screen cannot accidentally
    /// draw the Arabic title under an English heading. Anything that is not Arabic gets the
    /// English, because English is what the metadata file holds — a third language would need a
    /// column before it needed a branch.
    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }

    /// أذكار الصباح والمساء — the one chapter named in code rather than only in data.
    ///
    /// It has to be, because two things outside the corpus point straight at it: Home's shortcut
    /// circle and the `noor://adhkar?period=…` deep link, neither of which can ask a database
    /// which chapter a reader meant. Naming it here rather than spelling the string at both call
    /// sites means there is one place to look when the slug changes — and
    /// `AdhkarRepositoryTests` asserts the shipped corpus still has it, so the day it does not
    /// is a failing test rather than a shortcut that opens an empty screen.
    static let morningAndEveningID = "morning-evening"
}
