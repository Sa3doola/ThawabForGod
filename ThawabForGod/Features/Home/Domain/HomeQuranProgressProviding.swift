//
//  HomeQuranProgressProviding.swift
//  ThawabForGod
//

import Foundation

/// What Home needs to know about the Quran, and nothing more.
///
/// A protocol so Home never sees the user-data store or the corpus: the Quran feature adapts
/// itself to this, and a test hands Home a fake. Pure Swift on purpose.
@MainActor
protocol HomeQuranProgressProviding: AnyObject {
    /// Waits for any reader session that is still writing its position, so the read that follows
    /// cannot race the write.
    func settle() async

    /// The last ayah read, or `nil` if nothing has been read or the stored one no longer exists.
    func lastReadAyah() async -> VerseReference?

    /// A chapter's name in the given language, or `nil` where the corpus cannot answer.
    func surahName(_ surah: Int, in language: AppLanguage) async -> String?
}
