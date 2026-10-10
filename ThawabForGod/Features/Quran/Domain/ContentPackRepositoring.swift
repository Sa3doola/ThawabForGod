//
//  ContentPackRepositoring.swift
//  ThawabForGod
//

import Foundation

/// The translation, tafsir and surah-info packs that ship in the app. Offline only: there is
/// nothing to download or delete, only what is bundled.
///
/// **Found, not listed** (T15). Each pack is a `<kind>-<id>.sqlite` file that describes itself in
/// its own `pack` table, so the store discovers them by file prefix — the two builds bundle
/// different sets, and a manifest would be one more file each build had to agree with.
nonisolated protocol ContentPackStoring: Sendable {
    /// Every bundled pack, ordered by kind and then by file name.
    func installed() async -> [ContentPack]
    /// Where a pack's sqlite file is, or nil if it is not bundled.
    func url(for pack: ContentPackID) async -> URL?
}

nonisolated enum ContentPackError: Error, Equatable {
    case notInstalled(ContentPackID)
    case wrongKind(ContentPackID)
}

/// Translations from the bundled packs.
nonisolated protocol TranslationRepositoring: Sendable {
    /// Bundled translation packs.
    func installed() async -> [ContentPack]
    /// The ayah in each of `packs`, in that order; packs that are not installed are skipped.
    func text(for ayah: VerseReference, packs: [ContentPackID]) async throws -> [TranslationText]
    /// A whole surah in one query (separated mode), by ayah.
    func texts(surah: Int, pack: ContentPackID) async throws -> [VerseReference: TranslationText]
}

/// Tafsir from the bundled packs.
nonisolated protocol TafsirRepositoring: Sendable {
    /// Bundled tafsir packs.
    func installed() async -> [ContentPack]
    /// The entry covering `ayah` in `pack`: its group's text and the group's range.
    ///
    /// **`nil` is an answer** (T16): the commentary passes over this ayah — it has no row of its
    /// own and no group covers it. Never a neighbour's note. Throws `ContentPackError.notInstalled`
    /// for a pack that is not a bundled tafsir, so "silent" and "missing" stay two different things
    /// on screen.
    func tafsir(for ayah: VerseReference, pack: ContentPackID) async throws -> TafsirEntry?
}

/// Surah introductions from the bundled surah-info packs (QUL only: a Tanzil build has none, and
/// the screen hides the row).
nonisolated protocol SurahInfoRepositoring: Sendable {
    /// Bundled surah-info packs.
    func installed() async -> [ContentPack]
    /// The pack to show in an interface language: the one in that language, else nil — there is
    /// no Arabic surah info, so the Arabic interface shows none rather than English text.
    func pack(for language: AppLanguage) async -> ContentPack?
    /// The surah's introduction in `pack`; nil if the pack has none for it.
    func info(surah: Int, pack: ContentPackID) async throws -> SurahInfo?
}
