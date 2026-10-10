//
//  QuranMetadata.swift
//  ThawabForGod
//

import Foundation

/// Where juz, hizb and rub (quarter) divisions begin, and the sajdah ayahs, for one Mushaf layout.
///
/// The pages are optional for the reason `Surah.startPage` is: the Tanzil fallback knows where a
/// division begins in the *text*, but not on which page of the printed Mushaf.
nonisolated struct QuranMetadata: Sendable, Hashable {
    nonisolated struct Start: Sendable, Hashable {
        let number: Int
        /// Page of the start ayah's first word, where ۞ is printed.
        let page: Int?
        let ayah: VerseReference
    }

    nonisolated struct Sajdah: Sendable, Hashable {
        let number: Int
        /// Page of the ayah's end, where ۩ is printed.
        let page: Int?
        let ayah: VerseReference
        /// "Required" (4 ayahs) in QUL's words — Tanzil's "obligatory"; the others are optional.
        let isRequired: Bool
    }

    let juz: [Start]
    let hizb: [Start]
    let rub: [Start]
    let sajdahs: [Sajdah]

    static let empty = QuranMetadata(juz: [], hizb: [], rub: [], sajdahs: [])
}
