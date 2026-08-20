//
//  QuranProgressUseCase.swift
//  ThawabForGod
//

import Foundation

/// What the Quran screens do with the reader's own marks.
///
/// Separate from `GetQuranUseCase` rather than folded into it, though that type's documentation
/// anticipated this slice landing "here": a use case named `Get` that also writes would be a
/// naming lie, and the two have different dependencies — one reads a bundled corpus, the other
/// reads and writes the user's store. The view model holds both, which is the same arrangement
/// `TasbihUseCase` reaches by combining a catalog and a progress repository.
///
/// The clock is injected for the same reason `SettingsViewModel`'s is: a test that asserts on
/// ordering should not have to race the real one.
nonisolated struct QuranProgressUseCase: Sendable {
    private let repository: any QuranProgressRepositoring
    private let now: @Sendable () -> Date

    init(
        repository: any QuranProgressRepositoring,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.repository = repository
        self.now = now
    }

    func bookmarks() async throws -> [QuranBookmark] {
        try await repository.bookmarks()
    }

    /// Sets whether a verse is kept.
    ///
    /// The caller states the end state it wants rather than asking for a toggle. A toggle has to
    /// read first to know which way to go, which makes two quick taps depend on the order their
    /// reads complete in; `setBookmark(true,…)` twice is simply true, whatever order it lands in.
    func setBookmark(_ isBookmarked: Bool, for reference: VerseReference) async throws {
        if isBookmarked {
            try await repository.addBookmark(reference, at: now())
        } else {
            try await repository.removeBookmark(reference)
        }
    }

    func lastRead() async throws -> ReadingPosition? {
        try await repository.lastRead()
    }

    func recordLastRead(_ reference: VerseReference) async throws {
        try await repository.recordLastRead(reference, at: now())
    }
}
