//
//  TasbihDhikr.swift
//  ThawabForGod
//

import Foundation

/// A phrase the counter can count, and how many of it makes a lap.
///
/// Read from the corpus, so it is content rather than code: adding a sixth preset is a rebuild of
/// `corpus.sqlite`, not an edit here.
///
/// The `id` is load-bearing in a way the adhkar ids are not — the SwiftData progress store keys a
/// user's saved count on it, so renaming one orphans whatever they had counted. `Resources/Corpus/README.md`
/// says the same thing next to the data.
nonisolated struct TasbihDhikr: Identifiable, Hashable, Sendable {

    /// Stable, human-readable, and permanent: `"subhanallah"`, `"alhamdulillah"`.
    let id: String

    /// The phrase itself, vowelled. Always Arabic, shown to every user whatever their language.
    let arabicText: String

    /// What it means, in the reader's language. `nil` when that language is Arabic — the phrase
    /// *is* the dhikr for them, and there is nothing to translate it into.
    let translation: String?

    /// How many recitations make one lap. Always at least one; the corpus constrains it and the
    /// mapper clamps it, because a target of zero is a counter that can never complete.
    let targetCount: Int
}
