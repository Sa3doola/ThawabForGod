//
//  BookmarkRecord.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData's representation of a `Bookmark`. Stays inside `Data`: a `@Model` instance is
/// bound to the context that fetched it and must never cross an actor boundary — the domain
/// value type is what travels.
@Model
nonisolated final class BookmarkRecord {
    var id: UUID = UUID()
    var reference: String = ""
    var note: String?
    var createdAt: Date = Date()

    init(id: UUID, reference: String, note: String?, createdAt: Date) {
        self.id = id
        self.reference = reference
        self.note = note
        self.createdAt = createdAt
    }

    convenience init(_ bookmark: Bookmark) {
        self.init(
            id: bookmark.id,
            reference: bookmark.reference,
            note: bookmark.note,
            createdAt: bookmark.createdAt
        )
    }

    var domainValue: Bookmark {
        Bookmark(id: id, reference: reference, note: note, createdAt: createdAt)
    }

    func apply(_ bookmark: Bookmark) {
        reference = bookmark.reference
        note = bookmark.note
        createdAt = bookmark.createdAt
    }
}
