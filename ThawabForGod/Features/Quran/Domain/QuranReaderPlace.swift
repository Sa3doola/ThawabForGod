//
//  QuranReaderPlace.swift
//  ThawabForGod
//

import Foundation

/// Where a `GoToTarget` lands in the loaded corpus: an ayah and, where the build has printed pages,
/// the page. One target positions both display modes at once, so switching mode afterwards never
/// has to guess (Mushaf's `ReaderModel.go(to:)`).
nonisolated struct QuranReaderPlace: Equatable, Sendable {
    let ayah: VerseReference
    /// `nil` in a corpus without the printed pages.
    let page: Int?
    /// The target named one ayah: show it selected.
    let selectsAyah: Bool

    /// `nil` when the corpus does not contain the target. That includes every `.page` in the Tanzil
    /// build: it has no pages, and one of its page numbers is not a V2 page number, so a page is
    /// never mapped to anything else.
    static func resolve(_ target: GoToTarget, in corpus: QuranCorpus) -> QuranReaderPlace? {
        switch target {
        case .page(let number):
            guard let first = corpus.page(number)?.firstAyah else { return nil }
            return QuranReaderPlace(ayah: first, page: number, selectsAyah: false)

        case .ayah(let reference):
            guard corpus.ayah(reference) != nil else { return nil }
            return QuranReaderPlace(
                ayah: reference, page: corpus.pageNumber(for: reference), selectsAyah: true)

        case .surah(let number):
            guard let surah = corpus.surah(number) else { return nil }
            return QuranReaderPlace(
                ayah: VerseReference(surah: number, verse: 1), page: surah.startPage, selectsAyah: false)

        case .juz(let number):
            return division(corpus.metadata.juz, number: number)

        case .hizb(let number):
            return division(corpus.metadata.hizb, number: number)
        }
    }

    private static func division(_ starts: [QuranMetadata.Start], number: Int) -> QuranReaderPlace? {
        guard let start = starts.first(where: { $0.number == number }) else { return nil }
        return QuranReaderPlace(ayah: start.ayah, page: start.page, selectsAyah: false)
    }
}
