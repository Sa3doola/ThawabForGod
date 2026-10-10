//
//  QuranCorpus.swift
//  ThawabForGod
//

import Foundation

/// The whole Quran in one Mushaf style, loaded once, with lookup indices.
///
/// In the Tanzil fallback `pages` is empty and every page number is `nil`: the text, the surahs
/// and the divisions are all there, the printed layout is not (`QuranCapabilities`).
nonisolated struct QuranCorpus: Sendable {
    let style: MushafStyle
    let surahs: [Surah]
    let ayahs: [Ayah]
    let pages: [MushafPage]
    /// Juz, hizb and quarter starts and sajdahs for this style.
    let metadata: QuranMetadata
    /// What draws the empty surah header frame in `QuranFace.quranCommon` (QUL ligature
    /// "surah_header"), for themes that tint the header.
    var surahHeaderFrame: String? = nil

    /// Index into `ayahs` of each surah's first ayah (index 0 = surah 1).
    private let surahStart: [Int]
    /// Margin markers by page number, worked out once at load.
    private let marginMarkers: [Int: [MushafMarginMarker]]

    init(style: MushafStyle, surahs: [Surah], ayahs: [Ayah], pages: [MushafPage], metadata: QuranMetadata = .empty) {
        self.style = style
        self.surahs = surahs
        self.ayahs = ayahs
        self.pages = pages
        self.metadata = metadata
        var markers: [Int: [MushafMarginMarker]] = [:]
        for page in pages {
            let onPage = MushafMarginMarker.markers(on: page, metadata: metadata)
            if !onPage.isEmpty { markers[page.number] = onPage }
        }
        marginMarkers = markers
        var start: [Int] = []
        var offset = 0
        for surah in surahs {
            start.append(offset)
            offset += surah.ayahCount
        }
        surahStart = start
    }

    /// Whether this corpus carries the printed pages — `false` in the Tanzil fallback.
    var hasPages: Bool { !pages.isEmpty }

    func surah(_ number: Int) -> Surah? {
        surahs.indices.contains(number - 1) ? surahs[number - 1] : nil
    }

    func ayah(_ id: VerseReference) -> Ayah? {
        guard let surah = surah(id.surah), (1...surah.ayahCount).contains(id.verse) else { return nil }
        return ayahs[surahStart[id.surah - 1] + id.verse - 1]
    }

    /// The next ayah in Quran order (2:286 → 3:1); nil after 114:6.
    func ayah(after id: VerseReference) -> VerseReference? {
        guard let surah = surah(id.surah) else { return nil }
        if id.verse < surah.ayahCount { return VerseReference(surah: id.surah, verse: id.verse + 1) }
        return self.surah(id.surah + 1).map { VerseReference(surah: $0.number, verse: 1) }
    }

    /// The previous ayah in Quran order (3:1 → 2:286); nil before 1:1.
    func ayah(before id: VerseReference) -> VerseReference? {
        if id.verse > 1 { return VerseReference(surah: id.surah, verse: id.verse - 1) }
        return surah(id.surah - 1).map { VerseReference(surah: $0.number, verse: $0.ayahCount) }
    }

    func ayahs(inSurah number: Int) -> ArraySlice<Ayah> {
        guard let surah = surah(number) else { return [] }
        let start = surahStart[number - 1]
        return ayahs[start..<(start + surah.ayahCount)]
    }

    /// The page's juz, hizb, quarter and sajdah labels, in line order.
    func marginMarkers(page number: Int) -> [MushafMarginMarker] {
        marginMarkers[number] ?? []
    }

    func page(_ number: Int) -> MushafPage? {
        pages.indices.contains(number - 1) ? pages[number - 1] : nil
    }

    /// Page on which the ayah starts; `nil` for an ayah outside the corpus, and for every ayah in
    /// the Tanzil fallback.
    func pageNumber(for id: VerseReference) -> Int? {
        ayah(id)?.page
    }

    /// The basmala as written in the data: the text of 1:1.
    var basmala: String {
        ayahs.first?.text ?? ""
    }
}
