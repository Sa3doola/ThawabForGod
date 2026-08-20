//
//  QuranProgressRepository.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData-backed bookmarks and last-read position.
///
/// `@ModelActor` gives this actor its own `ModelContext` on its own executor, so a save happens
/// off the main actor and never touches the context SwiftUI draws from — the same shape
/// `TasbihProgressRepository` uses. Only `QuranBookmark` and `ReadingPosition` values cross the
/// boundary; no `@Model` ever does.
@ModelActor
actor QuranProgressRepository: QuranProgressRepositoring {

    // MARK: Bookmarks

    func bookmarks() throws -> [QuranBookmark] {
        let descriptor = FetchDescriptor<QuranBookmarkRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainValue)
    }

    /// Keeps a verse, or leaves the existing row alone if it is already kept.
    ///
    /// Returning early rather than overwriting `createdAt` is deliberate: the list is ordered by
    /// that date, so re-saving a verse the reader already had would silently move it to the top
    /// of their bookmarks for no reason they asked for.
    func addBookmark(_ reference: VerseReference, at date: Date) throws {
        guard try record(for: reference) == nil else { return }

        modelContext.insert(
            QuranBookmarkRecord(QuranBookmark(reference: reference, createdAt: date))
        )
        try modelContext.save()
    }

    func removeBookmark(_ reference: VerseReference) throws {
        guard let existing = try record(for: reference) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    /// `#Predicate` cannot close over a struct's properties, so the two `Int`s are lifted into
    /// locals first — otherwise the macro tries to capture `reference` itself and fails to build.
    private func record(for reference: VerseReference) throws -> QuranBookmarkRecord? {
        let surah = reference.surah
        let verse = reference.verse

        var descriptor = FetchDescriptor<QuranBookmarkRecord>(
            predicate: #Predicate { $0.surah == surah && $0.verse == verse }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: Last read

    func lastRead() throws -> ReadingPosition? {
        try positionRecord()?.domainValue
    }

    /// Upsert onto the single row — see `ReadingPositionRecord` for why there is exactly one.
    func recordLastRead(_ reference: VerseReference, at date: Date) throws {
        let position = ReadingPosition(reference: reference, updatedAt: date)

        if let existing = try positionRecord() {
            existing.apply(position)
        } else {
            modelContext.insert(
                ReadingPositionRecord(
                    surah: reference.surah,
                    verse: reference.verse,
                    updatedAt: date
                )
            )
        }
        try modelContext.save()
    }

    private func positionRecord() throws -> ReadingPositionRecord? {
        let key = ReadingPositionRecord.singletonKey

        var descriptor = FetchDescriptor<ReadingPositionRecord>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
