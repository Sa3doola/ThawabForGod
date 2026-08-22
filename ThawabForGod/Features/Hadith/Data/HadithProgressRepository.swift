//
//  HadithProgressRepository.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData-backed hadith bookmarks and last-read position.
///
/// `@ModelActor` gives this actor its own `ModelContext` on its own executor, so a save happens
/// off the main actor and never touches the context SwiftUI draws from — the same shape
/// `QuranProgressRepository` uses. Only `HadithBookmark` and `HadithReadingPosition` values cross
/// the boundary; no `@Model` ever does.
@ModelActor
actor HadithProgressRepository: HadithProgressRepositoring {

    // MARK: Bookmarks

    func bookmarks() throws -> [HadithBookmark] {
        let descriptor = FetchDescriptor<HadithBookmarkRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainValue)
    }

    /// Keeps a narration, or leaves the existing row alone if it is already kept.
    ///
    /// Returning early rather than overwriting `createdAt` is deliberate: the list is ordered by
    /// that date, so re-saving something the reader already had would silently move it to the top
    /// of their bookmarks for no reason they asked for.
    func addBookmark(_ bookmark: HadithBookmark) throws {
        guard try record(for: bookmark.id) == nil else { return }

        modelContext.insert(HadithBookmarkRecord(bookmark))
        try modelContext.save()
    }

    func removeBookmark(_ id: HadithID) throws {
        guard let existing = try record(for: id) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    /// `#Predicate` cannot close over a struct's properties, so the three parts are lifted into
    /// locals first — otherwise the macro tries to capture `id` itself and fails to build.
    private func record(for id: HadithID) throws -> HadithBookmarkRecord? {
        let collection = id.collection
        let number = id.number
        let part = id.part

        var descriptor = FetchDescriptor<HadithBookmarkRecord>(
            predicate: #Predicate {
                $0.collection == collection && $0.number == number && $0.part == part
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: Last read

    func lastRead() throws -> HadithReadingPosition? {
        try positionRecord()?.domainValue
    }

    /// Replaces the one row, or writes it if there is none.
    ///
    /// Deleting every row it finds rather than only the first: there should never be two, but if
    /// a bug or an interrupted migration ever left one behind, the next write is the cheapest
    /// place to be sure of it — and a silent second row would mean `lastRead()` returning
    /// whichever the store happened to hand back first.
    func recordLastRead(_ book: BookReference, at date: Date) throws {
        for existing in try modelContext.fetch(FetchDescriptor<HadithReadingPositionRecord>()) {
            modelContext.delete(existing)
        }

        modelContext.insert(
            HadithReadingPositionRecord(
                collection: book.collection,
                bookNumber: book.number,
                updatedAt: date
            )
        )
        try modelContext.save()
    }

    private func positionRecord() throws -> HadithReadingPositionRecord? {
        var descriptor = FetchDescriptor<HadithReadingPositionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
