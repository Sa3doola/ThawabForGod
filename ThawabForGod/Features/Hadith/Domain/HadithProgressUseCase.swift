//
//  HadithProgressUseCase.swift
//  ThawabForGod
//

import Foundation

/// What the reader has kept and where they left off, joined back to the narrations themselves.
///
/// Thicker than `GetHadithUseCase`, and this is where the thickness belongs: a bookmark is a
/// reference in one store and the words are in another, so *something* has to put them back
/// together. Doing it here rather than in the view model means the two repositories meet in
/// Domain, which is the only layer entitled to know that this feature has two of them.
nonisolated struct HadithProgressUseCase: Sendable {
    private let progress: any HadithProgressRepositoring
    private let corpus: any HadithRepositoring

    init(progress: any HadithProgressRepositoring, corpus: any HadithRepositoring) {
        self.progress = progress
        self.corpus = corpus
    }

    /// The kept narrations, newest first, each with its text.
    ///
    /// Ordered by when they were kept rather than by where they sit in the collections. The list
    /// is a record of what the reader did, and its most useful row is almost always the last one
    /// they added.
    ///
    /// A bookmark whose narration is no longer in the corpus is dropped rather than shown empty.
    /// That cannot happen today — the corpus only ever gains rows — but it is what a rebuild that
    /// regrouped a narration would produce, and a row with a citation and no text is worse than
    /// no row.
    func bookmarks() async throws -> [KeptHadith] {
        let kept = try await progress.bookmarks()
        guard !kept.isEmpty else { return [] }

        let narrations = try await corpus.hadiths(kept.map(\.id))
        let byID = Dictionary(narrations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return kept.compactMap { bookmark in
            byID[bookmark.id].map { KeptHadith(bookmark: bookmark, hadith: $0) }
        }
    }

    /// Whether a narration is kept. Asked by the reading screen, per narration on screen.
    func isBookmarked(_ id: HadithID, among bookmarks: [HadithBookmark]) -> Bool {
        bookmarks.contains { $0.id == id }
    }

    /// Keeps a narration if it is not kept, and forgets it if it is.
    ///
    /// One method rather than two, because the button is one button. The caller does not have to
    /// know which way it is going, which is what keeps the view from having to hold a copy of the
    /// answer and get it wrong.
    func toggleBookmark(_ hadith: Hadith, at date: Date = Date()) async throws {
        let kept = try await progress.bookmarks().contains { $0.id == hadith.id }

        if kept {
            try await progress.removeBookmark(hadith.id)
        } else {
            try await progress.addBookmark(HadithBookmark(hadith, createdAt: date))
        }
    }

    func lastRead() async throws -> HadithReadingPosition? {
        try await progress.lastRead()
    }

    func recordLastRead(_ book: BookReference, at date: Date = Date()) async throws {
        try await progress.recordLastRead(book, at: date)
    }
}

/// A bookmark and the narration it names, which is what a bookmarks list is a list of.
///
/// One value rather than two parallel arrays, so a row cannot be drawn with one reader's bookmark
/// date over another reader's text.
nonisolated struct KeptHadith: Identifiable, Hashable, Sendable {
    let bookmark: HadithBookmark
    let hadith: Hadith

    var id: HadithID { bookmark.id }
}
