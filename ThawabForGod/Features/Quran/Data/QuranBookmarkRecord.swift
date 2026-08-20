//
//  QuranBookmarkRecord.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData's representation of a `QuranBookmark`. Stays inside `Data`, as every `@Model` in
/// this project does: an instance is bound to the context that fetched it and must never cross an
/// actor boundary — the domain value type is what travels.
///
/// The verse is stored as two `Int`s rather than as `"2:255"`, so the list can be ordered and
/// filtered in the store instead of in memory after parsing every row back. `VerseReference` is
/// rebuilt at the boundary, which keeps the stringly-typed form out of the app entirely.
///
/// **Uniqueness is the repository's job, not the schema's.** SwiftData's `@Attribute(.unique)` is
/// per-property, and what has to be unique here is the *pair* — `#Unique` over several properties
/// is iOS 18 and this app targets 17. So `QuranProgressRepository` fetches before it inserts. The
/// cost is one extra read per bookmark; the alternative was a synthesized `"2:255"` key column
/// existing purely to carry a constraint.
///
/// Every property carries a default, which SwiftData needs for lightweight migration to add this
/// model to a store that already exists — and every installed copy has one, since the bookmarks
/// and tasbih schemas both shipped before this.
@Model
nonisolated final class QuranBookmarkRecord {
    var surah: Int = 0
    var verse: Int = 0
    var createdAt: Date = Date()

    init(surah: Int, verse: Int, createdAt: Date) {
        self.surah = surah
        self.verse = verse
        self.createdAt = createdAt
    }

    convenience init(_ bookmark: QuranBookmark) {
        self.init(
            surah: bookmark.reference.surah,
            verse: bookmark.reference.verse,
            createdAt: bookmark.createdAt
        )
    }

    var domainValue: QuranBookmark {
        QuranBookmark(
            reference: VerseReference(surah: surah, verse: verse),
            createdAt: createdAt
        )
    }
}
