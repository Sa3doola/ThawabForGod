//
//  Bookmark.swift
//  ThawabForGod
//

import Foundation

/// A saved place in the corpus. A plain value type: Domain knows nothing about SwiftData,
/// so nothing here is a live managed object and it crosses actors safely.
nonisolated struct Bookmark: Identifiable, Equatable, Sendable {
    let id: UUID
    var reference: String
    var note: String?
    var createdAt: Date

    init(id: UUID = UUID(), reference: String, note: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.reference = reference
        self.note = note
        self.createdAt = createdAt
    }
}
