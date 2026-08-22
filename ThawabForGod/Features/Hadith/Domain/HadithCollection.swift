//
//  HadithCollection.swift
//  ThawabForGod
//

import Foundation

/// One of the books of hadith the app carries, as the list screen needs it.
///
/// Two of them today, and the reason there are only two is not a matter of taste — see
/// `Tools/CorpusBuilder/build_hadith_db.py`. Sahih al-Bukhari and Sahih Muslim were compiled to
/// *exclude* what their authors did not accept, so the collection a narration is in is already
/// the statement about it. The four Sunan were not, and a narration from one of those needs a
/// grading beside it that this project cannot license. Nothing in this type says so, deliberately:
/// what may ship is a question about data, and the day a licence is settled a third row appears
/// here without a line of this feature changing.
nonisolated struct HadithCollection: Identifiable, Hashable, Sendable {

    /// The corpus's own name for it — `bukhari`. Stable, and what every other table joins on.
    let id: String

    /// The collection's title in Arabic, as it is printed — `صحيح البخاري`.
    let arabicName: String

    /// The same title in English — `Sahih al-Bukhari`.
    let englishName: String

    /// Its compiler, in Arabic.
    let arabicAuthor: String

    /// Its compiler, in English.
    let englishAuthor: String

    /// How many kitab it is divided into.
    ///
    /// Carried on the entity rather than counted by the screen: the list shows it without
    /// loading a single division, which is the same bargain `Surah.verseCount` makes.
    let bookCount: Int

    /// How many narrations it holds, across every kitab.
    let hadithCount: Int
}
