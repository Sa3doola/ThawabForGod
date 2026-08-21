//
//  Tafsir.swift
//  ThawabForGod
//

import Foundation

/// One commentary on the Quran: who wrote it, what language its notes are in, and why this
/// project believes it may ship it.
///
/// The licence travels *on the entity* rather than only in the build script, because it is shown:
/// a reader is entitled to know whose commentary they are reading and on what footing it arrived.
/// Settings → Sources says the same thing about every other corpus in the app.
nonisolated struct TafsirEdition: Identifiable, Hashable, Sendable {

    /// A stable slug — `jalalayn`. Chosen by the build, never derived from the name, so a
    /// stored preference keeps naming the same commentary after a rebuild.
    let id: String

    let arabicName: String
    let englishName: String
    let arabicAuthor: String
    let englishAuthor: String

    /// The language the *notes* are written in, which is not the language of the app.
    ///
    /// Its own field because it decides how the note is drawn — direction, script, VoiceOver
    /// voice — and because the app cannot yet assume the two agree: everything shippable today
    /// is Arabic, whatever language the interface is in.
    let language: AppLanguage

    /// Why it may be redistributed, in words — "Public domain — completed 1505 CE (911 AH)".
    let licence: String
}

/// What a commentary has to say about one verse.
///
/// A type rather than a bare `String` because the edition travels with the text: a note drawn on
/// screen without saying whose it is invites the reader to take it for the app's own voice, which
/// is the one thing a religious app must never do.
nonisolated struct TafsirNote: Hashable, Sendable {
    let reference: VerseReference
    let edition: TafsirEdition
    let text: String
}

/// Reads the commentaries. Every method is a read; the corpus is unchanging.
nonisolated protocol TafsirRepositoring: Sendable {

    /// Every edition the bundle carries, in the order the build wrote them.
    func editions() async throws -> [TafsirEdition]

    /// What one edition says about one verse, or `nil` where it says nothing.
    ///
    /// **`nil` is an answer, not a failure.** Al-Jalalayn passes over 226 verses — the plain
    /// formulas that need no gloss — and a caller must render that as "this commentary has no
    /// note here" rather than as an error, an empty page, or the note belonging to the verse
    /// above. The last of those would be the worst: a gloss of one verse printed under another.
    func note(for reference: VerseReference, in edition: TafsirEdition.ID) async throws -> TafsirNote?
}
