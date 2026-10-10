//
//  QuranRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Quran text, Mushaf layout and metadata, from whichever Quran database is bundled.
///
/// Mushaf's `QuranRepository` under this project's `-ing` name. Every method is `@concurrent`, as
/// it was there (T13): the whole-corpus load reads about a hundred thousand rows and must never run
/// on the main actor, which this module's default isolation would otherwise give it.
///
/// Anything with a page number depends on the Mushaf style, and on the build having pages at all:
/// in the Tanzil fallback `capabilities()` lacks `.mushafPages`, the page numbers it returns are
/// `nil`, and `page(_:style:)` and `pageNumber(for:style:)` throw `QuranDataError.unsupported`.
nonisolated protocol QuranRepositoring: Sendable {
    /// What the bundled database carries (`meta.capabilities`).
    @concurrent func capabilities() async throws -> QuranCapabilities
    /// Everything the reader needs, loaded once at launch.
    @concurrent func loadCorpus(style: MushafStyleID) async throws -> QuranCorpus
    @concurrent func surahs(style: MushafStyleID) async throws -> [Surah]
    @concurrent func page(_ number: Int, style: MushafStyleID) async throws -> MushafPage
    @concurrent func ayahs(surah: Int, style: MushafStyleID) async throws -> [Ayah]
    /// Page on which the ayah starts.
    @concurrent func pageNumber(for ayah: VerseReference, style: MushafStyleID) async throws -> Int
    @concurrent func metadata(style: MushafStyleID) async throws -> QuranMetadata
}

nonisolated enum QuranDataError: Error, Equatable {
    case missingResource(String)
    case invalidRow(String)
    /// The bundled database does not carry what was asked for — pages, in the Tanzil fallback.
    case unsupported(QuranCapabilities)
}
