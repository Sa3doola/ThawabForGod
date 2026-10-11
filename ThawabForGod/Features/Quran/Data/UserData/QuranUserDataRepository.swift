//
//  QuranUserDataRepository.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// The reader's bookmarks, notes, highlights and reading position, on a `@ModelActor` so SwiftData
/// work leaves the main actor and only values come back.
///
/// Uniqueness per ayah is enforced here, not by the schema: every write fetches all rows for the
/// ayah, updates the first and deletes the rest, and `marks()` keeps the newest row per ayah.
@ModelActor
actor QuranUserDataRepository: QuranUserDataRepositoring, QuranReadingPositionRepositoring {

    // MARK: Marks

    func marks() async throws -> QuranUserMarks {
        let bookmarks = Self.newestPerAyah(try modelContext.fetch(FetchDescriptor<AyahBookmarkRecord>()), in: modelContext)
        let notes = Self.newestPerAyah(try modelContext.fetch(FetchDescriptor<AyahNoteRecord>()), in: modelContext)
        let highlights = Self.newestPerAyah(try modelContext.fetch(FetchDescriptor<AyahHighlightRecord>()), in: modelContext)
        if modelContext.hasChanges { try modelContext.save() }

        return QuranUserMarks(
            bookmarks: bookmarks.map {
                QuranBookmark(ayah: VerseReference(surah: $0.surah, verse: $0.verse), createdAt: $0.createdAt)
            },
            notes: notes.map {
                QuranNote(
                    ayah: VerseReference(surah: $0.surah, verse: $0.verse), text: $0.text,
                    createdAt: $0.createdAt, updatedAt: $0.updatedAt
                )
            },
            // A row with an unknown colour is skipped, not deleted: a newer build may know it.
            highlights: highlights.compactMap { row in
                HighlightColor(rawValue: row.colorRaw).map {
                    QuranHighlight(
                        ayah: VerseReference(surah: row.surah, verse: row.verse), color: $0,
                        createdAt: row.createdAt, updatedAt: row.updatedAt
                    )
                }
            }
        )
    }

    func setBookmarked(_ isBookmarked: Bool, ayah: VerseReference, at date: Date) async throws {
        let existing = try bookmarks(for: ayah)
        if isBookmarked {
            guard existing.isEmpty else {
                // Already kept: no-op, which preserves `createdAt`. Stray duplicates go.
                if existing.count > 1 {
                    existing.dropFirst().forEach(modelContext.delete)
                    try modelContext.save()
                }
                return
            }
            modelContext.insert(AyahBookmarkRecord(surah: ayah.surah, verse: ayah.verse, createdAt: date, updatedAt: date))
        } else {
            existing.forEach(modelContext.delete)
        }
        try modelContext.save()
    }

    func setNote(_ text: String, ayah: VerseReference, at date: Date) async throws {
        let existing = try notes(for: ayah)
        if let text = QuranNote.normalizedText(text) {
            if let note = existing.first {
                existing.dropFirst().forEach(modelContext.delete)
                if note.text != text {
                    note.text = text
                    note.updatedAt = date
                }
            } else {
                modelContext.insert(AyahNoteRecord(surah: ayah.surah, verse: ayah.verse, text: text, createdAt: date, updatedAt: date))
            }
        } else {
            existing.forEach(modelContext.delete)
        }
        if modelContext.hasChanges { try modelContext.save() }
    }

    func setHighlight(_ color: HighlightColor?, ayah: VerseReference, at date: Date) async throws {
        let existing = try highlights(for: ayah)
        if let color {
            if let highlight = existing.first {
                existing.dropFirst().forEach(modelContext.delete)
                if highlight.colorRaw != color.rawValue {
                    highlight.colorRaw = color.rawValue
                    highlight.updatedAt = date
                }
            } else {
                modelContext.insert(
                    AyahHighlightRecord(surah: ayah.surah, verse: ayah.verse, colorRaw: color.rawValue, createdAt: date, updatedAt: date)
                )
            }
        } else {
            existing.forEach(modelContext.delete)
        }
        if modelContext.hasChanges { try modelContext.save() }
    }

    func removeAllMarks() async throws {
        try modelContext.fetch(FetchDescriptor<AyahBookmarkRecord>()).forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<AyahNoteRecord>()).forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<AyahHighlightRecord>()).forEach(modelContext.delete)
        if modelContext.hasChanges { try modelContext.save() }
    }

    // MARK: Reading position

    func readingPosition() async throws -> QuranReadingPosition? {
        let rows = try modelContext.fetch(FetchDescriptor<QuranReadingPositionRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        return rows.first.map {
            QuranReadingPosition(ayah: VerseReference(surah: $0.surah, verse: $0.verse), updatedAt: $0.updatedAt)
        }
    }

    func recordReadingPosition(_ ayah: VerseReference, at date: Date) async throws {
        let rows = try modelContext.fetch(FetchDescriptor<QuranReadingPositionRecord>())
        if let row = rows.first {
            rows.dropFirst().forEach(modelContext.delete)
            row.surah = ayah.surah
            row.verse = ayah.verse
            row.updatedAt = date
        } else {
            modelContext.insert(QuranReadingPositionRecord(surah: ayah.surah, verse: ayah.verse, updatedAt: date))
        }
        try modelContext.save()
    }

    // MARK: Fetching

    // Predicates read lifted locals, never a property of a struct.

    private func bookmarks(for ayah: VerseReference) throws -> [AyahBookmarkRecord] {
        let surah = ayah.surah, verse = ayah.verse
        return try modelContext.fetch(FetchDescriptor<AyahBookmarkRecord>(predicate: #Predicate { $0.surah == surah && $0.verse == verse }))
    }

    private func notes(for ayah: VerseReference) throws -> [AyahNoteRecord] {
        let surah = ayah.surah, verse = ayah.verse
        return try modelContext.fetch(FetchDescriptor<AyahNoteRecord>(predicate: #Predicate { $0.surah == surah && $0.verse == verse }))
    }

    private func highlights(for ayah: VerseReference) throws -> [AyahHighlightRecord] {
        let surah = ayah.surah, verse = ayah.verse
        return try modelContext.fetch(FetchDescriptor<AyahHighlightRecord>(predicate: #Predicate { $0.surah == surah && $0.verse == verse }))
    }

    /// One row per ayah, the most recently updated; the others are deleted.
    private static func newestPerAyah<Row: AyahRow>(_ rows: [Row], in context: ModelContext) -> [Row] {
        var kept: [VerseReference: Row] = [:]
        for row in rows {
            let key = VerseReference(surah: row.surah, verse: row.verse)
            if let other = kept[key] {
                let (newer, older) = row.updatedAt > other.updatedAt ? (row, other) : (other, row)
                kept[key] = newer
                context.delete(older)
            } else {
                kept[key] = row
            }
        }
        return Array(kept.values)
    }
}

/// A stored row addressed by `(surah, verse)` with an update time.
private nonisolated protocol AyahRow: PersistentModel {
    var surah: Int { get }
    var verse: Int { get }
    var updatedAt: Date { get }
}

extension AyahBookmarkRecord: AyahRow {}
extension AyahNoteRecord: AyahRow {}
extension AyahHighlightRecord: AyahRow {}
